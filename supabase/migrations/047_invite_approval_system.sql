-- GrubShelf Migration 047: Invite approval workflow columns and RPCs

ALTER TABLE household_invites
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Extend invite status values (keep backward-compatible defaults)
ALTER TABLE household_invites DROP CONSTRAINT IF EXISTS household_invites_status_check;
ALTER TABLE household_invites ADD CONSTRAINT household_invites_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'accepted', 'cancelled', 'expired'));

CREATE OR REPLACE FUNCTION public.approve_household_invite(p_invite_id UUID)
RETURNS SETOF household_invites
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
    v_inviter_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve invites';
    END IF;

    SELECT household_id, invited_by
    INTO v_household_id, v_inviter_id
    FROM household_invites
    WHERE invite_id = p_invite_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Invite not found or access denied';
    END IF;

    IF v_inviter_id IS NOT NULL AND v_inviter_id != auth.uid() THEN
        PERFORM create_notification(
            v_inviter_id,
            'invite_approved',
            'Invite Approved',
            'Your household invite has been approved by an admin',
            jsonb_build_object('invite_id', p_invite_id)
        );
    END IF;

    PERFORM log_audit_event(
        'invite_approved',
        'household_invites',
        p_invite_id,
        jsonb_build_object('approved_by', auth.uid())
    );

    RETURN QUERY
    UPDATE household_invites
    SET status = 'approved', approved_by = auth.uid(), approved_at = NOW()
    WHERE invite_id = p_invite_id AND status = 'pending'
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_household_invite(
    p_invite_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS SETOF household_invites
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
    v_inviter_id UUID;
    v_body TEXT;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject invites';
    END IF;

    SELECT household_id, invited_by
    INTO v_household_id, v_inviter_id
    FROM household_invites
    WHERE invite_id = p_invite_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Invite not found or access denied';
    END IF;

    v_body := 'Your household invite was rejected';
    IF p_reason IS NOT NULL AND char_length(trim(p_reason)) > 0 THEN
        v_body := v_body || ': ' || p_reason;
    END IF;

    IF v_inviter_id IS NOT NULL AND v_inviter_id != auth.uid() THEN
        PERFORM create_notification(
            v_inviter_id,
            'invite_rejected',
            'Invite Rejected',
            v_body,
            jsonb_build_object('invite_id', p_invite_id, 'reason', p_reason)
        );
    END IF;

    PERFORM log_audit_event(
        'invite_rejected',
        'household_invites',
        p_invite_id,
        jsonb_build_object('rejected_by', auth.uid(), 'reason', p_reason)
    );

    RETURN QUERY
    UPDATE household_invites
    SET status = 'rejected', approved_by = auth.uid(), approved_at = NOW(), rejection_reason = p_reason
    WHERE invite_id = p_invite_id AND status = 'pending'
    RETURNING *;
END;
$$;

-- Accept only admin-approved invites (or legacy pending for backward compatibility during rollout)
CREATE OR REPLACE FUNCTION public.accept_household_invite(p_invite_id UUID)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite household_invites%ROWTYPE;
    v_member_count INT;
BEGIN
    SELECT * INTO v_invite
    FROM household_invites
    WHERE invite_id = p_invite_id
      AND status IN ('pending', 'approved')
      AND expires_at > now();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invite not found, expired, rejected, or already used';
    END IF;

    IF v_invite.invited_email != (SELECT email FROM auth.users WHERE id = auth.uid()) THEN
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
        is_owner = FALSE,
        updated_at = now()
    WHERE user_id = auth.uid();

    UPDATE household_invites
    SET status = 'accepted'
    WHERE invite_id = p_invite_id;

    PERFORM log_audit_event(
        'member_joined',
        'users',
        auth.uid(),
        jsonb_build_object('household_id', v_invite.household_id, 'invite_id', p_invite_id)
    );

    RETURN QUERY SELECT * FROM users WHERE user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_household_invite(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_household_invite(UUID, TEXT) TO authenticated;
