-- Configure Vault secrets project_url and live_stream_cron_secret first.
-- The latter must match CRON_SECRET in Edge Function secrets; never put it
-- in the app or in committed SQL. See README for setup.
create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'project_url')
     or not exists (select 1 from vault.decrypted_secrets where name = 'live_stream_cron_secret') then
    raise exception 'Add project_url and live_stream_cron_secret to Supabase Vault first.';
  end if;
end $$;

select cron.schedule(
  'check-live-streams',
  '* * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'project_url') || '/functions/v1/check-live-streams',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets
                        where name = 'live_stream_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $job$
);
