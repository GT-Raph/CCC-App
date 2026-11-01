-- Lets church staff post news, events, sermons and ministries from the app.
-- Run once in the SQL Editor after schema.sql (or content.sql). Safe to run
-- again, and run it again after updating the app. Then add the first super
-- admin in Table Editor -> staff (see README): no SQL needs to be written.
begin;

-- Staff ---------------------------------------------------------------------
-- One row per staff member, by the email they sign in with (lower case).
-- Leave branch_id empty for an HQ admin (the app's name for a church-wide
-- admin): every branch, church-wide news, sermons and ministries, and
-- all-branch events. Set branch_id to limit someone to that branch's
-- content. Tick super_admin (HQ admins only) for the people who decide who
-- is staff: only super admins add, change or remove staff, and the church
-- always keeps at least one. The account's email must be confirmed before it
-- counts.

create table if not exists public.staff (
  email text primary key
    check (email = lower(btrim(email)) and email like '%_@_%'),
  branch_id uuid references public.branches(id) on delete cascade,
  added_at timestamptz not null default now()
);

-- Super admins came after the first release; older databases gain the column
-- here.
alter table public.staff
  add column if not exists super_admin boolean not null default false;
alter table public.staff drop constraint if exists staff_super_admin_church_wide;
alter table public.staff add constraint staff_super_admin_church_wide
  check (not super_admin or branch_id is null);

-- Before super admins, every HQ admin managed staff. So that someone still
-- can, a database with HQ admins but no super admin makes the HQ admin who
-- was added first its super admin; they can appoint others from the app.
update public.staff
set super_admin = true
where email = (
    select s.email from public.staff s
    where s.branch_id is null
    order by s.added_at, s.email
    limit 1
  )
  and not exists (select 1 from public.staff s where s.super_admin);

alter table public.staff enable row level security;

-- The signed-in member's staff row: none (not staff), or one whose branch_id
-- is empty for church-wide admins and whose super_admin marks those who
-- manage staff.
create or replace function public.staff_role()
returns table (branch_id uuid, super_admin boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select s.branch_id, s.super_admin
  from public.staff s
  join auth.users u on lower(u.email) = s.email
  where u.id = auth.uid()
    and u.email_confirmed_at is not null
$$;

-- The same without super_admin, for the content rules below and for app
-- versions from before super admins.
create or replace function public.staff_scope()
returns table (branch_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select r.branch_id from public.staff_role() r
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.staff_scope())
$$;

create or replace function public.is_church_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.staff_scope() s where s.branch_id is null)
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.staff_role() r where r.super_admin)
$$;

-- Whether the signed-in member may manage content for a branch; an empty
-- target means church-wide content, which only church-wide admins manage.
create or replace function public.can_manage(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_scope() s
    where s.branch_id is null or s.branch_id = target
  )
$$;

revoke all on function public.staff_role() from public, anon;
revoke all on function public.staff_scope() from public, anon;
revoke all on function public.is_staff() from public, anon;
revoke all on function public.is_church_admin() from public, anon;
revoke all on function public.is_super_admin() from public, anon;
revoke all on function public.can_manage(uuid) from public, anon;
grant execute on function public.staff_role() to authenticated;
grant execute on function public.staff_scope() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_church_admin() to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.can_manage(uuid) to authenticated;

grant select, insert, update, delete on public.staff to authenticated;

drop policy if exists "Church admins manage staff" on public.staff;
drop policy if exists "Super admins manage staff" on public.staff;
create policy "Super admins manage staff"
  on public.staff
  for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Refuses to remove or demote the last super admin, from the app or the
-- dashboard, so the church can't lock itself out of managing staff.
create or replace function public.keep_a_super_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.super_admin and (tg_op = 'DELETE' or not new.super_admin) then
    -- Two super admins removing each other at once must not both succeed.
    perform pg_advisory_xact_lock(hashtext('public.staff super admins'));
    if not exists (
      select 1 from public.staff s
      where s.super_admin and s.email <> old.email
    ) then
      raise exception 'The church needs at least one super admin.'
        using errcode = 'CC001',
          hint = 'Make someone else a super admin first.';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists keep_a_super_admin on public.staff;
create trigger keep_a_super_admin
  before update or delete on public.staff
  for each row execute function public.keep_a_super_admin();

-- Content -------------------------------------------------------------------
-- Staff see everything they manage (including scheduled news) and may add,
-- change and remove it. Members and guests keep read-only access.

grant insert, update, delete on public.news to authenticated;
grant insert, update, delete on public.ministries to authenticated;
grant insert, update, delete on public.events to authenticated;
grant insert, update, delete on public.sermons to authenticated;

-- A sermon without a branch is heard by every branch, like church-wide news.
-- can_manage(null) holds only for HQ admins, so branch staff can't post one.
alter table public.sermons alter column branch_id drop not null;

drop policy if exists "Staff see their news" on public.news;
create policy "Staff see their news"
  on public.news for select to authenticated
  using (public.can_manage(branch_id));
drop policy if exists "Staff add news" on public.news;
create policy "Staff add news"
  on public.news for insert to authenticated
  with check (public.can_manage(branch_id));
drop policy if exists "Staff edit news" on public.news;
create policy "Staff edit news"
  on public.news for update to authenticated
  using (public.can_manage(branch_id))
  with check (public.can_manage(branch_id));
drop policy if exists "Staff remove news" on public.news;
create policy "Staff remove news"
  on public.news for delete to authenticated
  using (public.can_manage(branch_id));

drop policy if exists "Staff add ministries" on public.ministries;
create policy "Staff add ministries"
  on public.ministries for insert to authenticated
  with check (public.can_manage(branch_id));
drop policy if exists "Staff edit ministries" on public.ministries;
create policy "Staff edit ministries"
  on public.ministries for update to authenticated
  using (public.can_manage(branch_id))
  with check (public.can_manage(branch_id));
drop policy if exists "Staff remove ministries" on public.ministries;
create policy "Staff remove ministries"
  on public.ministries for delete to authenticated
  using (public.can_manage(branch_id));

-- An event for every branch is church-wide content.
drop policy if exists "Staff add events" on public.events;
create policy "Staff add events"
  on public.events for insert to authenticated
  with check (
    public.can_manage(branch_id)
    and (not for_all_branches or public.is_church_admin())
  );
drop policy if exists "Staff edit events" on public.events;
create policy "Staff edit events"
  on public.events for update to authenticated
  using (
    public.can_manage(branch_id)
    and (not for_all_branches or public.is_church_admin())
  )
  with check (
    public.can_manage(branch_id)
    and (not for_all_branches or public.is_church_admin())
  );
drop policy if exists "Staff remove events" on public.events;
create policy "Staff remove events"
  on public.events for delete to authenticated
  using (
    public.can_manage(branch_id)
    and (not for_all_branches or public.is_church_admin())
  );

drop policy if exists "Staff add sermons" on public.sermons;
create policy "Staff add sermons"
  on public.sermons for insert to authenticated
  with check (public.can_manage(branch_id));
drop policy if exists "Staff edit sermons" on public.sermons;
create policy "Staff edit sermons"
  on public.sermons for update to authenticated
  using (public.can_manage(branch_id))
  with check (public.can_manage(branch_id));
drop policy if exists "Staff remove sermons" on public.sermons;
create policy "Staff remove sermons"
  on public.sermons for delete to authenticated
  using (public.can_manage(branch_id));

-- Who joined a ministry, for the staff who manage it: names and branches
-- only, never emails or other profile details.
create or replace function public.signups_for_ministry(target uuid)
returns table (member text, member_branch text, joined_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(nullif(btrim(p.full_name), ''), 'Member'),
    b.name,
    mm.joined_at
  from public.ministry_members mm
  join public.ministries m on m.id = mm.ministry_id
  left join public.profiles p on p.id = mm.user_id
  left join public.branches b on b.id = p.branch_id
  where mm.ministry_id = target
    and public.can_manage(m.branch_id)
  order by mm.joined_at desc
$$;

revoke all on function public.signups_for_ministry(uuid) from public, anon;
grant execute on function public.signups_for_ministry(uuid) to authenticated;

-- Media ---------------------------------------------------------------------
-- Staff upload photos and recordings from the app. The buckets stay public
-- for reading; only staff can add, replace or remove files, and only of the
-- expected kinds.

update storage.buckets
set
  file_size_limit = 10 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
where id in ('news', 'events', 'ministries');

update storage.buckets
set
  allowed_mime_types = array[
    'audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/wav',
    'audio/x-wav', 'audio/ogg'
  ]
where id = 'sermons';

drop policy if exists "Staff see church media" on storage.objects;
create policy "Staff see church media"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('news', 'events', 'ministries', 'sermons')
    and public.is_staff()
  );
drop policy if exists "Staff upload church media" on storage.objects;
create policy "Staff upload church media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('news', 'events', 'ministries', 'sermons')
    and public.is_staff()
  );
drop policy if exists "Staff replace church media" on storage.objects;
create policy "Staff replace church media"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('news', 'events', 'ministries', 'sermons')
    and public.is_staff()
  )
  with check (
    bucket_id in ('news', 'events', 'ministries', 'sermons')
    and public.is_staff()
  );
drop policy if exists "Staff remove church media" on storage.objects;
create policy "Staff remove church media"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('news', 'events', 'ministries', 'sermons')
    and public.is_staff()
  );

commit;
