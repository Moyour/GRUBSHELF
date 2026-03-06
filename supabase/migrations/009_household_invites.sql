-- ============================================================
-- Household Invites table + RLS policies
-- Also fixes: users SELECT policy to allow reading household members
-- ============================================================

-- 1. Fix: Allow members to read other users in the same household
--    The existing "Users can read own row" policy blocks fetchMembers().
CREATE POLICY "Members can read household members"
    ON users FOR SELECT
    USING (household_id = get_my_household_id());

-- 2. Allow admins to update other members in their household (for role changes, removal)
CREATE POLICY "Admins can update household members"
    ON users FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

-- 3. Household invites table
CREATE TABLE household_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    invited_email TEXT NOT NULL,
    invited_by UUID NOT NULL REFERENCES users(user_id),
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'cancelled')) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

-- Only one pending invite per email per household
CREATE UNIQUE INDEX idx_unique_pending_invite
    ON household_invites (household_id, invited_email)
    WHERE status = 'pending';

CREATE INDEX idx_invites_email_status
    ON household_invites (invited_email, status);

-- 4. RLS for household_invites
ALTER TABLE household_invites ENABLE ROW LEVEL SECURITY;

-- Admins can create invites for their household
CREATE POLICY "Admins can insert invites"
    ON household_invites FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

-- Admins can view invites for their household
CREATE POLICY "Admins can read household invites"
    ON household_invites FOR SELECT
    USING (household_id = get_my_household_id());

-- Invited users can see invites addressed to their email
CREATE POLICY "Users can read own invites"
    ON household_invites FOR SELECT
    USING (
        invited_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    );

-- Admins can cancel invites for their household
CREATE POLICY "Admins can update household invites"
    ON household_invites FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

-- 5. RPC to accept an invite (needs SECURITY DEFINER to update both tables)
CREATE OR REPLACE FUNCTION public.accept_household_invite(p_invite_id UUID)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invite household_invites%ROWTYPE;
    v_member_count INT;
BEGIN
    -- Fetch the invite
    SELECT * INTO v_invite
    FROM household_invites
    WHERE invite_id = p_invite_id
      AND status = 'pending'
      AND expires_at > now();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invite not found, expired, or already used';
    END IF;

    -- Verify the caller's email matches the invite
    IF v_invite.invited_email != (SELECT email FROM auth.users WHERE id = auth.uid()) THEN
        RAISE EXCEPTION 'This invite is not for your email address';
    END IF;

    -- Check household member limit (20)
    SELECT COUNT(*) INTO v_member_count
    FROM users
    WHERE household_id = v_invite.household_id;

    IF v_member_count >= 20 THEN
        RAISE EXCEPTION 'Household has reached the maximum of 20 members';
    END IF;

    -- Link user to household
    UPDATE users
    SET household_id = v_invite.household_id,
        role = 'member',
        updated_at = now()
    WHERE user_id = auth.uid();

    -- Mark invite as accepted
    UPDATE household_invites
    SET status = 'accepted'
    WHERE invite_id = p_invite_id;

    RETURN QUERY SELECT * FROM users WHERE user_id = auth.uid();
END;
$$;
