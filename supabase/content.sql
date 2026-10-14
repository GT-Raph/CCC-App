-- Adds real-content tables to an existing CCC database.
-- Requires the existing branches and profiles tables. No news, events,
-- ministry descriptions, membership counts or users are seeded.
begin;
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

commit;
