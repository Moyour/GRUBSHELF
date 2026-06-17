-- 029: Re-schedule the daily-digest cron job using Supabase Vault for secrets.
--
-- Migration 028 originally relied on
--   current_setting('app.settings.supabase_url')
--   current_setting('app.settings.service_role_key')
-- which required `ALTER DATABASE postgres SET app.settings.* = '...'`. On
-- hosted Supabase that statement is no longer permitted from the SQL editor
-- (ERROR 42501: permission denied to set parameter), so the cron job in 028
-- would fail at runtime.
--
-- This migration replaces the schedule with one that reads both the project
-- URL and the service-role key from `vault.decrypted_secrets`. The secret
-- values themselves must be inserted once via the SQL editor (they are not
-- committed to source). Run, with your project's service_role key pasted in:
--
--   SELECT vault.create_secret(
--     'https://dpsyrzffwpfrsrsmsidm.supabase.co', 'project_url'
--   );
--   SELECT vault.create_secret(
--     '<service_role_key>', 'service_role_key'
--   );
--
-- After both secrets exist, the next cron tick (or a manual `cron.schedule`
-- test invocation) will succeed.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS supabase_vault;

GRANT USAGE ON SCHEMA net TO postgres;

DO $outer$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-digest-email') THEN
    PERFORM cron.unschedule('daily-digest-email');
  END IF;
END
$outer$;

SELECT cron.schedule(
  'daily-digest-email',
  '0 8 * * *',
  $cron$
  SELECT net.http_post(
    url     := (
      SELECT decrypted_secret
      FROM vault.decrypted_secrets
      WHERE name = 'project_url'
      LIMIT 1
    ) || '/functions/v1/send-daily-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'service_role_key'
        LIMIT 1
      )
    ),
    body    := '{}'::jsonb
  );
  $cron$
);
