-- 030: Re-add email_notifications_enabled column to public.users.
--
-- Migration 026 is recorded in supabase_migrations.schema_migrations but the
-- column is missing from public.users on the remote DB, causing the daily
-- digest edge function to fail with:
--   ERROR 42703: column "email_notifications_enabled" does not exist
-- (Schema drift, probably from an earlier rebuild or a 026 application that
--  was rolled back without rolling back the migrations table.)
--
-- IF NOT EXISTS makes this safe to apply regardless of the current state.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email_notifications_enabled BOOLEAN NOT NULL DEFAULT true;
