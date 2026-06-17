-- 028: Schedule the daily digest email via pg_cron + pg_net
-- Fires every day at 08:00 UTC, calling the send-daily-digest edge function.

-- Enable required extensions (idempotent)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant usage so pg_cron can use pg_net
GRANT USAGE ON SCHEMA net TO postgres;

-- Schedule the daily digest cron job (idempotent: skip if already exists)
DO $outer$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'daily-digest-email'
  ) THEN
    PERFORM cron.schedule(
      'daily-digest-email',
      '0 8 * * *',
      $inner$
      SELECT net.http_post(
        url    := current_setting('app.settings.supabase_url') || '/functions/v1/send-daily-digest',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body   := '{}'::jsonb
      );
      $inner$
    );
  END IF;
END
$outer$;
