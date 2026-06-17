-- Migration 067: Fix invite acceptance flow
--
-- BUG 1 (case sensitivity)
-- create_household_invite stores invited_email as `LOWER(p_invited_email)`, but
-- accept_household_invite compared with `v_invite.invited_email != (SELECT email FROM auth.users WHERE id = auth.uid())`.
-- If the JWT email had any uppercase characters (typical for Apple Private Relay
-- or users who typed mixed case during signup) the equality silently failed and
-- the invitee got "This invite is not for your email address" or, worse, the
-- accept appeared to succeed but never bound the household.
--
-- BUG 2 (auth.users coupling)
-- The same function read auth.users; while SECURITY DEFINER lets it succeed,
-- it is unnecessary coupling. auth.email() reads the same value from the JWT
-- without any table access and matches what the RLS policies on
-- household_invites/households were just changed to use (migration 066).
--
-- Also pins search_path for determinism.

CREATE OR REPLACE FUNCTION public.accept_household_invite(p_invite_id uuid)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_invite household_invites%ROWTYPE;
    v_member_count INT;
    v_caller_email TEXT;
BEGIN
    v_caller_email := lower(coalesce(auth.email(), ''));
    IF v_caller_email = '' THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_invite
    FROM household_invites
    WHERE invite_id = p_invite_id
      AND status IN ('pending', 'approved')
      AND expires_at > now();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invite not found, expired, or already used';
    END IF;

    IF lower(v_invite.invited_email) != v_caller_email THEN
        RAISE EXCEPTION 'This invite is not for your email address';
    END IF;

    SELECT COUNT(*) INTO v_member_count
    FROM users
    WHERE household_id = v_invite.household_id;

    IF v_member_count >= 20 THEN
        RAISE EXCEPTION 'Household has reached the maximum of 20 members';
    END IF;

    UPDATE users
    SET household_id = v_invite.household_id,
        role = 'member',
        updated_at = now()
    WHERE user_id = auth.uid();

    UPDATE household_invites
    SET status = 'accepted'
    WHERE invite_id = p_invite_id;

    RETURN QUERY SELECT * FROM users WHERE user_id = auth.uid();
END;
$function$;

COMMENT ON FUNCTION public.accept_household_invite(uuid) IS
'Accepts a pending/approved household invite. Uses case-insensitive comparison between auth.email() (JWT claim) and the invite''s invited_email, both lowercased. Pins search_path for determinism.';
