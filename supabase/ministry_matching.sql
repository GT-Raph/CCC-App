-- Matches members with ministries. Members tell the app their date of birth,
-- gender, marital status and whether they're a student; staff say who each
-- ministry is for; members who qualify are added to it automatically.
-- Run after schema.sql (or content.sql) and staff.sql. Safe to run again.
begin;

-- Members' details ------------------------------------------------------------
-- Only the member can see or change their row. Staff never see it: the
-- matching below runs inside the database. No row means the app hasn't asked
-- yet; a row with every detail empty means the member chose to skip.

create table if not exists public.member_details (
  user_id uuid primary key default auth.uid()
    references auth.users(id) on delete cascade,
  birth_date date check (birth_date >= date '1900-01-01'),
  gender text check (gender in ('male', 'female')),
  marital_status text check (
    marital_status in ('single', 'married', 'widowed', 'divorced', 'separated')
  ),
  student boolean,
  updated_at timestamptz not null default now()
);

alter table public.member_details enable row level security;
grant select, insert, update, delete on public.member_details to authenticated;

drop policy if exists "Members see their own details" on public.member_details;
create policy "Members see their own details"
  on public.member_details for select to authenticated
  using (auth.uid() = user_id);
drop policy if exists "Members add their own details" on public.member_details;
create policy "Members add their own details"
  on public.member_details for insert to authenticated
  with check (auth.uid() = user_id);
drop policy if exists "Members change their own details" on public.member_details;
create policy "Members change their own details"
  on public.member_details for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
drop policy if exists "Members remove their own details" on public.member_details;
create policy "Members remove their own details"
  on public.member_details for delete to authenticated
  using (auth.uid() = user_id);

drop trigger if exists set_member_details_updated_at on public.member_details;
create trigger set_member_details_updated_at
  before update on public.member_details
  for each row execute procedure public.set_updated_at();

-- Who each ministry is for ----------------------------------------------------
-- With auto_assign on, members who meet every rule set here are added for
-- them. Empty rules don't restrict: no ages means any age, no marital
-- statuses means any. A ministry that adds members needs at least one rule,
-- so switching it on can never add the whole church by mistake.

alter table public.ministries
  add column if not exists auto_assign boolean not null default false,
  add column if not exists min_age integer,
  add column if not exists max_age integer,
  add column if not exists for_gender text,
  add column if not exists for_marital_statuses text[] not null default '{}',
  add column if not exists for_students boolean;

alter table public.ministries drop constraint if exists ministries_ages_valid;
alter table public.ministries add constraint ministries_ages_valid check (
  (min_age is null or min_age between 0 and 120)
  and (max_age is null or max_age between 0 and 120)
  and (min_age is null or max_age is null or min_age <= max_age)
);
alter table public.ministries drop constraint if exists ministries_gender_valid;
alter table public.ministries add constraint ministries_gender_valid
  check (for_gender is null or for_gender in ('male', 'female'));
alter table public.ministries drop constraint if exists ministries_marital_valid;
alter table public.ministries add constraint ministries_marital_valid check (
  for_marital_statuses
    <@ array['single', 'married', 'widowed', 'divorced', 'separated']
);
alter table public.ministries drop constraint if exists ministries_auto_assign_has_rule;
alter table public.ministries add constraint ministries_auto_assign_has_rule check (
  not auto_assign
  or min_age is not null
  or max_age is not null
  or for_gender is not null
  or cardinality(for_marital_statuses) > 0
  or for_students is not null
);

-- Memberships -----------------------------------------------------------------
-- Memberships the matching made can be taken away by it when the member no
-- longer qualifies; ones members made themselves never are.

alter table public.ministry_members
  add column if not exists added_automatically boolean not null default false;

-- Ministries a member left, so the matching never adds them back. Joining
-- again from the app forgets it. Only the database itself reads this.
create table if not exists public.ministry_opt_outs (
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  left_at timestamptz not null default now(),
  primary key (ministry_id, user_id)
);

alter table public.ministry_opt_outs enable row level security;
revoke all on public.ministry_opt_outs from anon, authenticated;

-- Remembers members leaving and rejoining. The matching sets ccc.matching
-- while it adds and removes memberships itself, which aren't the member's
-- choice.
create or replace function public.remember_ministry_choice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('ccc.matching', true), '') = 'on' then
    return null;
  end if;
  if tg_op = 'DELETE' then
    -- Not when the ministry or the account itself is being deleted.
    if exists (select 1 from public.ministries m where m.id = old.ministry_id)
      and exists (select 1 from auth.users u where u.id = old.user_id)
    then
      insert into public.ministry_opt_outs (ministry_id, user_id)
      values (old.ministry_id, old.user_id)
      on conflict do nothing;
    end if;
  else
    delete from public.ministry_opt_outs o
    where o.ministry_id = new.ministry_id and o.user_id = new.user_id;
  end if;
  return null;
end;
$$;

drop trigger if exists remember_ministry_choice on public.ministry_members;
create trigger remember_ministry_choice
  after insert or delete on public.ministry_members
  for each row execute function public.remember_ministry_choice();

-- Matching --------------------------------------------------------------------

-- Whether a member qualifies for a ministry's automatic membership: it adds
-- members automatically, belongs to their branch or to every branch, and
-- every rule it sets holds. A rule needs the detail it checks, so a member
-- who skipped a detail is never matched by a rule on it.
create or replace function public.qualifies_for(
  m public.ministries,
  d public.member_details,
  member_branch uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    m.auto_assign
    and (m.branch_id is null or m.branch_id = member_branch)
    and (
      (m.min_age is null and m.max_age is null)
      or (
        d.birth_date is not null
        and (m.min_age is null
          or extract(year from age(current_date, d.birth_date)) >= m.min_age)
        and (m.max_age is null
          or extract(year from age(current_date, d.birth_date)) <= m.max_age)
      )
    )
    and (m.for_gender is null or d.gender = m.for_gender)
    and (
      cardinality(m.for_marital_statuses) = 0
      or d.marital_status = any(m.for_marital_statuses)
    )
    and (m.for_students is null or d.student = m.for_students),
    false
  )
$$;

-- Brings automatic memberships up to date for one member, one ministry, or
-- (both empty) everyone. Adds members who qualify unless they left that
-- ministry before, and removes automatic memberships whose member no longer
-- qualifies while the ministry still adds members. Returns what it added.
create or replace function public.sync_ministry_members(
  only_member uuid,
  only_ministry uuid
)
returns table (added_ministry uuid, added_member uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('ccc.matching', 'on', true);

  delete from public.ministry_members mm
  using public.ministries m
  where m.id = mm.ministry_id
    and mm.added_automatically
    and m.auto_assign
    and (only_member is null or mm.user_id = only_member)
    and (only_ministry is null or mm.ministry_id = only_ministry)
    and not exists (
      select 1
      from public.member_details d
      left join public.profiles p on p.id = d.user_id
      where d.user_id = mm.user_id
        and public.qualifies_for(m, d, p.branch_id)
    );

  for added_ministry, added_member in
    insert into public.ministry_members as mm
      (ministry_id, user_id, added_automatically)
    select m.id, d.user_id, true
    from public.ministries m
    cross join public.member_details d
    left join public.profiles p on p.id = d.user_id
    where (only_member is null or d.user_id = only_member)
      and (only_ministry is null or m.id = only_ministry)
      and public.qualifies_for(m, d, p.branch_id)
      and not exists (
        select 1 from public.ministry_opt_outs o
        where o.ministry_id = m.id and o.user_id = d.user_id
      )
    on conflict (ministry_id, user_id) do nothing
    returning mm.ministry_id, mm.user_id
  loop
    return next;
  end loop;

  perform set_config('ccc.matching', '', true);
end;
$$;

-- The signed-in member's automatic ministries, brought up to date. The app
-- calls it when the member saves their details or changes branch, and when
-- it opens, since birthdays move people between age groups. Returns the
-- ministries just joined.
create or replace function public.match_my_ministries()
returns table (id uuid, name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  return query
    select m.id, m.name
    from public.sync_ministry_members(auth.uid(), null) s
    join public.ministries m on m.id = s.added_ministry
    order by m.sort_order, m.name;
end;
$$;

-- When staff create a ministry or change who it's for, its members are
-- brought up to date straight away.
create or replace function public.match_ministry_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.sync_ministry_members(null, new.id);
  return null;
end;
$$;

drop trigger if exists match_ministry_after_change on public.ministries;
create trigger match_ministry_after_change
  after insert or update of
    auto_assign, min_age, max_age, for_gender, for_marital_statuses,
    for_students, branch_id
  on public.ministries
  for each row execute function public.match_ministry_after_change();

revoke all on function public.remember_ministry_choice() from public, anon, authenticated;
revoke all on function public.qualifies_for(public.ministries, public.member_details, uuid)
  from public, anon, authenticated;
revoke all on function public.sync_ministry_members(uuid, uuid) from public, anon, authenticated;
revoke all on function public.match_ministry_after_change() from public, anon, authenticated;
revoke all on function public.match_my_ministries() from public, anon;
grant execute on function public.match_my_ministries() to authenticated;

commit;
