-- Run in Supabase SQL Editor before TestFlight / App Store release.
-- Replace project ref in dashboard links as needed.

-- 1) Latest migrations applied (compare to supabase/migrations/)
SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 15;

-- 2) Schema drift hotfixes (071–073)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'pantry_items'
  AND column_name IN ('storage_location', 'photo_path');

SELECT proname
FROM pg_proc
WHERE proname = 'log_audit_event';

SELECT to_regclass('public.household_barcode_labels');

-- 3) Push path
SELECT key, updated_at FROM push_config WHERE key IN ('project_url', 'service_role_key');
SELECT COUNT(*) AS device_tokens FROM push_device_tokens;

-- 4) Cron digest job
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'daily-digest-email';

-- 5) RLS enabled on core tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'users', 'households', 'pantry_items', 'shopping_items',
    'notifications', 'push_device_tokens', 'household_invites'
  );
