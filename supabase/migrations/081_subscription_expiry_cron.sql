-- 081_subscription_expiry_cron.sql
-- Schedule hourly cron to expire lapsed premium subscriptions.
-- expire_subscriptions() is defined in migration 077.
--
-- pg_cron is only available on Supabase Pro and above.
-- On the free tier this migration is a safe no-op; the expire-subscriptions
-- Edge Function serves as the fallback (called by an external scheduler).

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
    PERFORM cron.schedule(
        'expire-subscriptions',
        '0 * * * *',
        'SELECT expire_subscriptions();'
    );
    RAISE NOTICE 'pg_cron scheduled: expire-subscriptions every hour';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron not available (% — %), skipping cron schedule. Use the expire-subscriptions Edge Function instead.', SQLSTATE, SQLERRM;
END;
$$;
