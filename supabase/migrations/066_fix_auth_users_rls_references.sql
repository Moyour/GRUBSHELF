-- Migration 066: Fix RLS policies that referenced auth.users
--
-- ROOT CAUSE
-- The `authenticated` role does NOT have SELECT privilege on `auth.users`.
-- Two RLS policies were doing `SELECT email FROM auth.users WHERE id = auth.uid()`,
-- which raised Postgres error `42501: permission denied for table users`
-- as soon as those policies were evaluated for a signed-in user. That bubbled
-- up to the iOS app as "Failed to load profile — permission denied for table users".
--
-- FIX
-- Replace the auth.users lookup with `auth.email()`, which reads the email
-- claim directly from the JWT and requires no table privileges.
--
-- Also harden helper functions with an explicit search_path so they remain
-- deterministic regardless of caller configuration (advisor: function_search_path_mutable).

DROP POLICY IF EXISTS "Users can read own invites" ON public.household_invites;
CREATE POLICY "Users can read own invites"
    ON public.household_invites
    FOR SELECT
    USING (lower(invited_email) = lower(coalesce(auth.email(), '')));

DROP POLICY IF EXISTS "Users can read households they are invited to" ON public.households;
CREATE POLICY "Users can read households they are invited to"
    ON public.households
    FOR SELECT
    USING (
        household_id IN (
            SELECT household_invites.household_id
            FROM public.household_invites
            WHERE lower(household_invites.invited_email) = lower(coalesce(auth.email(), ''))
              AND household_invites.status = ANY (ARRAY['pending'::text, 'approved'::text])
              AND household_invites.expires_at > now()
        )
    );

ALTER FUNCTION public.get_my_household_id() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_household_admin() SET search_path = public, pg_catalog;

COMMENT ON POLICY "Users can read own invites" ON public.household_invites IS
'Allows users to read invites addressed to their email. Uses auth.email() (JWT claim) instead of querying auth.users, which the authenticated role cannot read.';

COMMENT ON POLICY "Users can read households they are invited to" ON public.households IS
'Allows users to read household info when they have a pending/approved invite. Uses auth.email() (JWT claim) instead of querying auth.users, which the authenticated role cannot read.';
