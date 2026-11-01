-- Lets ministries such as Media or Choir approve their new members. Staff
-- switch on needs_approval and name the ministry's leaders; members ask to
-- join; a leader (or staff who manage the ministry) approves or declines.
-- Run after schema.sql (or content.sql), staff.sql and ministry_matching.sql.
-- Safe to run again.
begin;

-- A ministry that approves its members never adds them automatically.
alter table public.ministries
  add column if not exists needs_approval boolean not null default false;
alter table public.ministries drop constraint if exists ministries_approval_or_automatic;
alter table public.ministries add constraint ministries_approval_or_automatic
  check (not (needs_approval and auto_assign));

-- Leaders ---------------------------------------------------------------------
-- One row per leader of a ministry, by the email they sign in with (lower
-- case). Leaders answer requests to join their ministry and nothing else;
-- staff who manage the ministry choose them. The email must be confirmed
-- before it counts.

create table if not exists public.ministry_leaders (
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  email text not null
    check (email = lower(btrim(email)) and email like '%_@_%'),
  added_at timestamptz not null default now(),
  primary key (ministry_id, email)
);

alter table public.ministry_leaders enable row level security;
revoke all on public.ministry_leaders from anon;
revoke update on public.ministry_leaders from authenticated;
grant select, insert, delete on public.ministry_leaders to authenticated;

-- Whether the signed-in member is staff who manage [target]'s content.
create or replace function public.manages_ministry(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ministries m
    where m.id = target and public.can_manage(m.branch_id)
  )
$$;

create or replace function public.leads_ministry(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.ministry_leaders l
    join auth.users u on lower(u.email) = l.email
    where l.ministry_id = target
      and u.id = auth.uid()
      and u.email_confirmed_at is not null
  )
$$;

-- Who answers requests to join [target]: its leaders, and the staff who
-- manage it.
create or replace function public.can_approve(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.leads_ministry(target) or public.manages_ministry(target)
$$;

drop policy if exists "Staff see ministry leaders" on public.ministry_leaders;
create policy "Staff see ministry leaders"
  on public.ministry_leaders for select to authenticated
  using (public.manages_ministry(ministry_id));
drop policy if exists "Staff add ministry leaders" on public.ministry_leaders;
create policy "Staff add ministry leaders"
  on public.ministry_leaders for insert to authenticated
  with check (public.manages_ministry(ministry_id));
drop policy if exists "Staff remove ministry leaders" on public.ministry_leaders;
create policy "Staff remove ministry leaders"
  on public.ministry_leaders for delete to authenticated
  using (public.manages_ministry(ministry_id));

-- Requests --------------------------------------------------------------------
-- One row per member asking to join a ministry: pending until a leader
-- answers. Approving adds the member and removes the request; declining
-- keeps it, so the member can see the answer, until they ask again.

create table if not exists public.ministry_requests (
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  primary key (ministry_id, user_id)
);

alter table public.ministry_requests enable row level security;
-- Members ask and leaders answer through the functions below.
revoke all on public.ministry_requests from anon;
revoke insert, update on public.ministry_requests from authenticated;
grant select, delete on public.ministry_requests to authenticated;

drop policy if exists "Members see their own requests" on public.ministry_requests;
create policy "Members see their own requests"
  on public.ministry_requests for select to authenticated
  using (auth.uid() = user_id);
drop policy if exists "Members withdraw their requests" on public.ministry_requests;
create policy "Members withdraw their requests"
  on public.ministry_requests for delete to authenticated
  using (auth.uid() = user_id and status = 'pending');

-- Joining ---------------------------------------------------------------------
-- Members can't add themselves to a ministry that needs approval, directly or
-- by moving a membership they have. Restrictive, so these hold whatever
-- other policies allow; approval adds members from inside the database.

create or replace function public.needs_approval(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ministries m where m.id = target and m.needs_approval
  )
$$;

-- Whether the signed-in member belongs to [target].
create or replace function public.in_ministry(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ministry_members mm
    where mm.ministry_id = target and mm.user_id = auth.uid()
  )
$$;

drop policy if exists "Approved ministries are joined through a leader" on public.ministry_members;
create policy "Approved ministries are joined through a leader"
  on public.ministry_members
  as restrictive
  for insert
  to authenticated
  with check (not public.needs_approval(ministry_id));

drop policy if exists "Approved ministries can't be moved into" on public.ministry_members;
create policy "Approved ministries can't be moved into"
  on public.ministry_members
  as restrictive
  for update
  to authenticated
  using (true)
  with check (
    not public.needs_approval(ministry_id)
    or public.in_ministry(ministry_id)
  );

-- Asks to join [target], or asks again after a decline. Nothing happens for
-- a member who already belongs to it.
create or replace function public.request_to_join(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to ask to join a ministry.' using errcode = 'CC001';
  end if;
  if not public.needs_approval(target) then
    raise exception 'This ministry doesn''t take requests; join it instead.'
      using errcode = 'CC001';
  end if;
  if public.in_ministry(target) then
    return;
  end if;
  insert into public.ministry_requests (ministry_id, user_id)
  values (target, auth.uid())
  on conflict (ministry_id, user_id) do update
    set status = 'pending', requested_at = now(), decided_at = null;
end;
$$;

-- Pending requests to join [target], for those who answer them: names and
-- branches only, never emails or other profile details.
create or replace function public.ministry_requests_for(target uuid)
returns table (
  user_id uuid,
  member text,
  member_branch text,
  requested_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.user_id,
    coalesce(nullif(btrim(p.full_name), ''), 'Member'),
    b.name,
    r.requested_at
  from public.ministry_requests r
  left join public.profiles p on p.id = r.user_id
  left join public.branches b on b.id = p.branch_id
  where r.ministry_id = target
    and r.status = 'pending'
    and public.can_approve(target)
  order by r.requested_at
$$;

-- Approves a request, adding the member, or declines it.
create or replace function public.answer_ministry_request(
  target uuid,
  member uuid,
  approve boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_approve(target) then
    raise exception 'Only the ministry''s leaders can answer its requests.'
      using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.ministry_requests r
    where r.ministry_id = target and r.user_id = member and r.status = 'pending'
  ) then
    raise exception 'This request has already been answered.'
      using errcode = 'CC001';
  end if;
  if approve then
    insert into public.ministry_members (ministry_id, user_id)
    values (target, member)
    on conflict do nothing;
    delete from public.ministry_requests r
    where r.ministry_id = target and r.user_id = member;
  else
    update public.ministry_requests r
    set status = 'declined', decided_at = now()
    where r.ministry_id = target and r.user_id = member;
  end if;
end;
$$;

-- The ministries whose requests the signed-in member answers, with how many
-- are waiting.
create or replace function public.ministries_to_approve()
returns table (id uuid, name text, waiting integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.id,
    m.name,
    (
      select count(*)::integer from public.ministry_requests r
      where r.ministry_id = m.id and r.status = 'pending'
    )
  from public.ministries m
  where m.needs_approval and public.can_approve(m.id)
  order by m.sort_order, m.name
$$;

revoke all on function public.manages_ministry(uuid) from public, anon;
revoke all on function public.leads_ministry(uuid) from public, anon;
revoke all on function public.can_approve(uuid) from public, anon;
revoke all on function public.needs_approval(uuid) from public, anon;
revoke all on function public.in_ministry(uuid) from public, anon;
revoke all on function public.request_to_join(uuid) from public, anon;
revoke all on function public.ministry_requests_for(uuid) from public, anon;
revoke all on function public.answer_ministry_request(uuid, uuid, boolean) from public, anon;
revoke all on function public.ministries_to_approve() from public, anon;
grant execute on function public.manages_ministry(uuid) to authenticated;
grant execute on function public.leads_ministry(uuid) to authenticated;
grant execute on function public.can_approve(uuid) to authenticated;
grant execute on function public.needs_approval(uuid) to authenticated;
grant execute on function public.in_ministry(uuid) to authenticated;
grant execute on function public.request_to_join(uuid) to authenticated;
grant execute on function public.ministry_requests_for(uuid) to authenticated;
grant execute on function public.answer_ministry_request(uuid, uuid, boolean) to authenticated;
grant execute on function public.ministries_to_approve() to authenticated;

commit;
