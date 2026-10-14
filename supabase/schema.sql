-- CCC member profiles, branches and sermons.
-- Passwords remain managed by Supabase Auth in auth.users and are never
-- copied into these tables. Safe to run again after changes.

-- Branches ------------------------------------------------------------------
-- The church's branches. Members choose one when they sign up, and sermons
-- are filed under one. Fill it with supabase/branches.sql, then edit it in
-- Table Editor.

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- The branch's Google Maps listing, as shown on the Church tab.
  google_place_id text unique,
  created_at timestamptz not null default now()
);

alter table public.branches enable row level security;
grant select on public.branches to anon, authenticated;

drop policy if exists "Anyone can see the branches" on public.branches;
create policy "Anyone can see the branches"
  on public.branches
  for select
  to anon, authenticated
  using (true);

-- Profiles ------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists branch_id uuid
    references public.branches(id) on delete set null;

alter table public.profiles enable row level security;

drop policy if exists "Members can view their own profile" on public.profiles;
create policy "Members can view their own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Members can update their own profile" on public.profiles;
create policy "Members can update their own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- The app saves the member's branch in their account details (branch_id);
-- this returns it when it names a real branch, else null.
create or replace function public.branch_from_metadata(metadata jsonb)
returns uuid
language plpgsql
stable
security definer set search_path = public
as $$
declare
  candidate uuid;
begin
  begin
    candidate := (metadata ->> 'branch_id')::uuid;
  exception when others then
    return null;
  end;
  return (select id from public.branches where id = candidate);
end;
$$;

-- Copies the member's name and branch into their profile when they sign up,
-- and again whenever they change them in the app.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, branch_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    public.branch_from_metadata(new.raw_user_meta_data)
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        branch_id = excluded.branch_id,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of raw_user_meta_data on auth.users
  for each row execute procedure public.handle_new_user();

-- Backfill profiles for accounts created before this schema was installed.
insert into public.profiles (id, full_name, branch_id)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', ''),
  public.branch_from_metadata(raw_user_meta_data)
from auth.users
on conflict (id) do nothing;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- Sermons -------------------------------------------------------------------
-- One row per recording. Staff post them from the app once staff.sql has
-- run (see README); without it only the dashboard can add or change them.
-- branch_id is the branch whose members hear it; leave it empty for a sermon
-- every branch hears (only HQ admins can post those).

create table if not exists public.sermons (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id) on delete cascade,
  title text not null,
  preacher text not null default '',
  preached_on date not null default current_date,
  description text not null default '',
  -- The file's path in the "sermons" bucket (e.g. botwe/2026-10-12.mp3), or
  -- a full https:// link to audio hosted elsewhere.
  audio_path text not null,
  -- Optional; shown on the card before the audio loads.
  duration_seconds integer check (duration_seconds is null or duration_seconds > 0),
  created_at timestamptz not null default now()
);

create index if not exists sermons_branch_newest
  on public.sermons (branch_id, preached_on desc);

alter table public.sermons enable row level security;
grant select on public.sermons to anon, authenticated;

drop policy if exists "Anyone can list sermons" on public.sermons;
create policy "Anyone can list sermons"
  on public.sermons
  for select
  to anon, authenticated
  using (true);

-- Public bucket: anyone with a sermon's link can stream it, and only the
-- dashboard can upload.
insert into storage.buckets (id, name, public)
values ('sermons', 'sermons', true)
on conflict (id) do nothing;

-- Events --------------------------------------------------------------------
-- branch_id is the branch holding the event; its YouTube live stream is the
-- event's stream. Members of that branch see the event; tick
-- for_all_branches to show it to every branch. Times are in UTC, which is
-- also Ghana time.

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  for_all_branches boolean not null default false,
  title text not null,
  starts_at timestamptz not null,
  -- Optional; the app takes events without one to last three hours.
  ends_at timestamptz,
  host text not null default '',
  address text not null default '',
  description text not null default '',
  -- Photos in the "events" bucket (e.g. botwe/harvest-2026.jpg), or full
  -- https:// links. The first one shows on the card.
  image_paths text[] not null default '{}',
  phone text not null default '',
  email text not null default '',
  website text not null default '',
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create index if not exists events_by_start on public.events (starts_at);
create index if not exists events_by_branch_start
  on public.events (branch_id, starts_at);

alter table public.events enable row level security;
grant select on public.events to anon, authenticated;

drop policy if exists "Anyone can see events" on public.events;
create policy "Anyone can see events"
  on public.events
  for select
  to anon, authenticated
  using (true);

insert into storage.buckets (id, name, public)
values ('events', 'events', true)
on conflict (id) do nothing;

-- Live streams --------------------------------------------------------------
-- Each branch's YouTube channel ID (starts with "UC"; see README). The
-- check-live-streams function watches these channels and writes what it
-- finds to live_streams, one row per branch. The app only reads that table
-- and hears about changes through Realtime.

alter table public.branches
  add column if not exists youtube_channel_id text
    check (youtube_channel_id is null
      or youtube_channel_id ~ '^UC[A-Za-z0-9_-]{22}$');

create table if not exists public.live_streams (
  branch_id uuid primary key references public.branches(id) on delete cascade,
  status text not null default 'offline'
    check (status in ('live', 'upcoming', 'offline')),
  video_id text,
  title text,
  scheduled_start_at timestamptz,
  actual_start_at timestamptz,
  -- When YouTube was last asked; the app ignores a "live" reading that is
  -- more than 20 minutes old.
  checked_at timestamptz,
  next_check_at timestamptz not null default now(),
  error text
);

alter table public.live_streams enable row level security;
grant select on public.live_streams to anon, authenticated;

drop policy if exists "Anyone can see live streams" on public.live_streams;
create policy "Anyone can see live streams"
  on public.live_streams
  for select
  to anon, authenticated
  using (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_streams'
  ) then
    alter publication supabase_realtime add table public.live_streams;
  end if;
end;
$$;

-- News ----------------------------------------------------------------------
-- Leave branch_id empty for church-wide news; set it for one branch's news.
-- Members see their branch's news and the church-wide news, newest first.
-- A future published_at schedules a post.

create table if not exists public.news (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id) on delete cascade,
  title text not null,
  subtitle text not null default '',
  -- The short text on the card; body is the full story.
  summary text not null default '',
  body text not null default '',
  -- Photos in the "news" bucket (e.g. harvest/choir.jpg) or https:// links.
  image_paths text[] not null default '{}',
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists news_by_date on public.news (published_at desc);

alter table public.news enable row level security;
grant select on public.news to anon, authenticated;

drop policy if exists "Anyone can read published news" on public.news;
create policy "Anyone can read published news"
  on public.news
  for select
  to anon, authenticated
  using (published_at <= now());

insert into storage.buckets (id, name, public)
values ('news', 'news', true)
on conflict (id) do nothing;

-- Ministries ----------------------------------------------------------------
-- Leave branch_id empty for a church-wide ministry; set it for one branch's.
-- Members join from the app; who joined is in ministry_members.

create table if not exists public.ministries (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id) on delete cascade,
  name text not null,
  -- Who it's for or what it does, e.g. "Women's fellowship".
  focus text not null default '',
  -- e.g. "Saturdays, 4:00 PM".
  meets text not null default '',
  venue text not null default '',
  -- Shown as "<label> members", e.g. "50+". Leave empty to hide it.
  members_label text not null default '',
  about text not null default '',
  -- Photos in the "ministries" bucket or https:// links.
  image_paths text[] not null default '{}',
  -- Lower numbers first; then by name.
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.ministries enable row level security;
grant select on public.ministries to anon, authenticated;

drop policy if exists "Anyone can see ministries" on public.ministries;
create policy "Anyone can see ministries"
  on public.ministries
  for select
  to anon, authenticated
  using (true);

insert into storage.buckets (id, name, public)
values ('ministries', 'ministries', true)
on conflict (id) do nothing;

create table if not exists public.ministry_members (
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (ministry_id, user_id)
);

alter table public.ministry_members enable row level security;
grant select, insert, update, delete on public.ministry_members to authenticated;

drop policy if exists "Members see their own ministries" on public.ministry_members;
create policy "Members see their own ministries"
  on public.ministry_members
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Members join ministries" on public.ministry_members;
create policy "Members join ministries"
  on public.ministry_members
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Upserting an existing membership is an update of the same row.
drop policy if exists "Members rejoin ministries" on public.ministry_members;
create policy "Members rejoin ministries"
  on public.ministry_members
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Members leave ministries" on public.ministry_members;
create policy "Members leave ministries"
  on public.ministry_members
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Who joined which ministry, with names and branches, for church admins
-- (Table Editor -> ministry_signups). Only the dashboard can read it.
create or replace view public.ministry_signups
with (security_invoker = true) as
select
  m.name as ministry,
  p.full_name as member,
  b.name as member_branch,
  mm.joined_at
from public.ministry_members mm
join public.ministries m on m.id = mm.ministry_id
left join public.profiles p on p.id = mm.user_id
left join public.branches b on b.id = p.branch_id;

revoke all on public.ministry_signups from anon, authenticated;
