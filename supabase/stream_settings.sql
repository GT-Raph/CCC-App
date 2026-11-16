-- Run after schema.sql and staff.sql, before deploying the updated checker.
-- Media leaders manage a branch's channel without becoming content admins.
begin;

alter table public.branches
  add column if not exists youtube_channel_handle text
    check (youtube_channel_handle is null or
      (char_length(youtube_channel_handle) between 2 and 101
       and youtube_channel_handle ~ '^@[^[:space:]/?#@]+$')),
  add column if not exists youtube_channel_revision bigint not null default 0;

create table if not exists public.branch_media_leaders (
  branch_id uuid not null references public.branches(id) on delete cascade,
  email text not null check (email = lower(btrim(email)) and email like '%_@_%'),
  primary key (branch_id, email)
);
alter table public.branch_media_leaders enable row level security;
revoke all on public.branch_media_leaders from anon, authenticated;
grant select, insert, delete on public.branch_media_leaders to authenticated;

drop policy if exists "Staff manage media leaders" on public.branch_media_leaders;
create policy "Staff manage media leaders" on public.branch_media_leaders
  for all to authenticated
  using (public.can_manage(branch_id))
  with check (public.can_manage(branch_id));

create or replace function public.can_manage_stream(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.can_manage(target) or exists (
    select 1 from public.branch_media_leaders l
    join auth.users u on lower(u.email) = l.email
    where l.branch_id = target and u.id = auth.uid()
      and u.email_confirmed_at is not null
  )
$$;

create or replace function public.stream_settings_for_me()
returns table (
  id uuid, name text, youtube_channel_id text, youtube_channel_handle text,
  status text, checked_at timestamptz, error text
)
language sql stable security definer set search_path = '' as $$
  select b.id, b.name, b.youtube_channel_id, b.youtube_channel_handle,
    s.status, s.checked_at, s.error
  from public.branches b left join public.live_streams s on s.branch_id = b.id
  where public.can_manage_stream(b.id)
  order by b.name
$$;

-- Invalidate the old stream immediately, even when an owner edits a channel
-- in the dashboard. Revision checks stop an in-flight reading restoring it.
create or replace function public.reset_changed_stream_channel()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.youtube_channel_id is distinct from old.youtube_channel_id
    or new.youtube_channel_handle is distinct from old.youtube_channel_handle then
    new.youtube_channel_revision := old.youtube_channel_revision + 1;
    insert into public.live_streams (branch_id) values (new.id)
    on conflict (branch_id) do update set
      status = 'offline', video_id = null, title = null,
      scheduled_start_at = null, actual_start_at = null, checked_at = null,
      error = null, next_check_at = now();
  end if;
  return new;
end;
$$;
drop trigger if exists reset_changed_stream_channel on public.branches;
create trigger reset_changed_stream_channel
  before update of youtube_channel_id, youtube_channel_handle on public.branches
  for each row execute function public.reset_changed_stream_channel();

-- Accepts a normalized channel ID or @handle; URLs are parsed in the app.
-- This function can change no other branch fields and grants no staff access.
create or replace function public.save_stream_channel(target uuid, channel text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  value text := nullif(btrim(channel), '');
begin
  if not public.can_manage_stream(target) then
    raise exception 'You cannot manage this branch''s live stream.' using errcode = '42501';
  end if;
  if value is not null and not (
    value ~ '^UC[A-Za-z0-9_-]{22}$' or
    (char_length(value) between 2 and 101 and value ~ '^@[^[:space:]/?#@]+$')
  ) then
    raise exception 'Enter a YouTube channel link, @handle or channel ID.' using errcode = 'CC001';
  end if;
  update public.branches set
    youtube_channel_id = case when value like 'UC%' then value end,
    youtube_channel_handle = case when value like '@%' then value end
  where id = target;
  if not found then
    raise exception 'This branch no longer exists.' using errcode = 'CC001';
  end if;
end;
$$;

-- Only the scheduled checker can publish a reading. The branch lock makes
-- checking the revision and writing the result atomic with channel changes.
create or replace function public.record_stream_reading(
  target uuid, revision bigint, reading jsonb
)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.branches b
    where b.id = target and b.youtube_channel_revision = revision
      and (b.youtube_channel_id is not null or b.youtube_channel_handle is not null)
    for update;
  if not found then return false; end if;
  if reading ? 'error' and reading->>'error' is not null then
    insert into public.live_streams (branch_id, error, next_check_at)
    values (target, reading->>'error', (reading->>'next_check_at')::timestamptz)
    on conflict (branch_id) do update
      set error = excluded.error, next_check_at = excluded.next_check_at;
  else
    insert into public.live_streams (
      branch_id, status, video_id, title, scheduled_start_at, actual_start_at,
      checked_at, next_check_at, error
    ) values (
      target, reading->>'status', reading->>'video_id', reading->>'title',
      (reading->>'scheduled_start_at')::timestamptz,
      (reading->>'actual_start_at')::timestamptz,
      (reading->>'checked_at')::timestamptz,
      (reading->>'next_check_at')::timestamptz, null
    ) on conflict (branch_id) do update set
      status = excluded.status, video_id = excluded.video_id, title = excluded.title,
      scheduled_start_at = excluded.scheduled_start_at,
      actual_start_at = excluded.actual_start_at, checked_at = excluded.checked_at,
      next_check_at = excluded.next_check_at, error = null;
  end if;
  return true;
end;
$$;

revoke all on function public.can_manage_stream(uuid) from public, anon;
revoke all on function public.stream_settings_for_me() from public, anon;
revoke all on function public.save_stream_channel(uuid, text) from public, anon;
revoke all on function public.reset_changed_stream_channel() from public, anon, authenticated;
revoke all on function public.record_stream_reading(uuid, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.can_manage_stream(uuid) to authenticated;
grant execute on function public.stream_settings_for_me() to authenticated;
grant execute on function public.save_stream_channel(uuid, text) to authenticated;
grant execute on function public.record_stream_reading(uuid, bigint, jsonb) to service_role;

commit;
