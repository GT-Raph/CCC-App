-- Lets confirmed ministry leaders set the existing membership requirements.
-- Run after ministry_approval.sql. Safe to run again; existing rules stay put.
begin;

-- Includes ministries with any joining mode, not just those taking requests.
create or replace function public.ministries_for_rules()
returns table (id uuid, name text, focus text, branch_id uuid, branches jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.name, m.focus, m.branch_id,
    case when b.id is null then null else jsonb_build_object('name', b.name) end
  from public.ministries m
  left join public.branches b on b.id = m.branch_id
  where public.can_approve(m.id)
  order by m.sort_order, m.name
$$;

-- A narrow write path: leaders cannot change content, branch, other leaders,
-- or delete a ministry. Existing constraints and matching triggers still apply.
create or replace function public.save_ministry_rules(
  target uuid,
  add_automatically boolean,
  minimum_age integer,
  maximum_age integer,
  gender text,
  marital_statuses text[],
  students boolean,
  require_approval boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.ministries m
  set auto_assign = add_automatically,
      min_age = minimum_age,
      max_age = maximum_age,
      for_gender = gender,
      for_marital_statuses = marital_statuses,
      for_students = students,
      needs_approval = require_approval
  where m.id = target and public.can_approve(m.id);
  if not found then
    raise exception 'You cannot change this ministry''s requirements.'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.ministries_for_rules() from public, anon;
revoke all on function public.save_ministry_rules(uuid, boolean, integer, integer, text, text[], boolean, boolean)
  from public, anon;
grant execute on function public.ministries_for_rules() to authenticated;
grant execute on function public.save_ministry_rules(uuid, boolean, integer, integer, text, text[], boolean, boolean)
  to authenticated;

commit;
