-- Run after staff.sql, ministry_approval.sql and stream_settings.sql.
-- Lets a signed-in member delete their own account from the app, as Google
-- Play and the App Store require. Safe to rerun.
begin;

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  my_email text;
begin
  if me is null then
    raise exception 'Sign in to delete your account.' using errcode = '42501';
  end if;
  select lower(u.email) into my_email from auth.users u where u.id = me;

  -- Appointments are kept by email, not by account, so they would outlive
  -- the account and pass to anyone who later signs up with the address.
  if my_email is not null then
    if exists (
      select 1 from public.staff s
      where lower(s.email) = my_email and s.super_admin
    ) and (select count(*) from public.staff s where s.super_admin) = 1 then
      raise exception 'You are the church''s only super admin. Make someone else a super admin, then delete your account.'
        using errcode = 'CC001';
    end if;
    delete from public.staff s where lower(s.email) = my_email;
    delete from public.ministry_leaders l where l.email = my_email;
    delete from public.branch_media_leaders l where l.email = my_email;
  end if;

  -- Photos and recordings a staff member uploaded belong to the church and
  -- stay. Detach them so they don't block deleting the account.
  begin
    update storage.objects o set owner = null where o.owner = me;
  exception when undefined_column or insufficient_privilege then
    null;
  end;

  -- The profile, member details, ministry memberships, opt-outs and join
  -- requests are deleted with the account (on delete cascade).
  delete from auth.users u where u.id = me;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

commit;
