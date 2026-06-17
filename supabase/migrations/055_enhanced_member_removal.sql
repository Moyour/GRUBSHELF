-- GrubShelf Migration 055: Enhanced member removal with history

CREATE TABLE IF NOT EXISTS removal_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    removed_user_id UUID NOT NULL,
    removed_user_name TEXT NOT NULL,
    removed_user_email TEXT NOT NULL,
    removed_by UUID NOT NULL REFERENCES users(user_id),
    reason TEXT,
    handle_pending_items TEXT,
    removed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_removal_history_household
    ON removal_history (household_id, removed_at DESC);

ALTER TABLE removal_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read household removal history"
    ON removal_history FOR SELECT
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

CREATE OR REPLACE FUNCTION public.remove_household_member(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_handle_pending_items TEXT DEFAULT 'keep'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_is_owner BOOLEAN;
    v_caller_household UUID;
    v_target_household UUID;
    v_target_role TEXT;
    v_target_is_owner BOOLEAN;
    v_target_name TEXT;
    v_target_email TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_handle_pending_items NOT IN ('keep', 'approve', 'reject') THEN
        RAISE EXCEPTION 'Invalid handle_pending_items: %', p_handle_pending_items;
    END IF;

    SELECT role, is_owner, household_id
    INTO v_caller_role, v_caller_is_owner, v_caller_household
    FROM users WHERE user_id = v_caller_id;

    SELECT role, is_owner, household_id, name, email
    INTO v_target_role, v_target_is_owner, v_target_household, v_target_name, v_target_email
    FROM users WHERE user_id = p_user_id;

    IF v_target_household IS NULL OR v_target_household != v_caller_household THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Cannot remove yourself. Use leave household instead';
    END IF;

    IF v_target_is_owner THEN
        RAISE EXCEPTION 'Cannot remove the household owner. Transfer ownership first';
    END IF;

    IF v_caller_is_owner THEN
        NULL;
    ELSIF v_caller_role = 'admin' AND v_target_role = 'member' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Insufficient permissions to remove this member';
    END IF;

    IF p_handle_pending_items = 'approve' THEN
        UPDATE pantry_items
        SET approval_status = 'approved', approved_by = v_caller_id, approved_at = NOW(), updated_at = NOW()
        WHERE created_by = p_user_id AND approval_status = 'pending';

        UPDATE shopping_items
        SET approval_status = 'approved', approved_by = v_caller_id, approved_at = NOW(), updated_at = NOW()
        WHERE created_by = p_user_id AND approval_status = 'pending';
    ELSIF p_handle_pending_items = 'reject' THEN
        UPDATE pantry_items
        SET approval_status = 'rejected',
            approved_by = v_caller_id,
            approved_at = NOW(),
            rejection_reason = 'User removed from household',
            updated_at = NOW()
        WHERE created_by = p_user_id AND approval_status = 'pending';

        UPDATE shopping_items
        SET approval_status = 'rejected',
            approved_by = v_caller_id,
            approved_at = NOW(),
            rejection_reason = 'User removed from household',
            updated_at = NOW()
        WHERE created_by = p_user_id AND approval_status = 'pending';
    END IF;

    INSERT INTO removal_history (
        household_id,
        removed_user_id,
        removed_user_name,
        removed_user_email,
        removed_by,
        reason,
        handle_pending_items
    )
    VALUES (
        v_caller_household,
        p_user_id,
        v_target_name,
        v_target_email,
        v_caller_id,
        p_reason,
        p_handle_pending_items
    );

    UPDATE users
    SET household_id = NULL, is_owner = FALSE, updated_at = NOW()
    WHERE user_id = p_user_id;

    PERFORM log_audit_event(
        'member_removed',
        'users',
        p_user_id,
        jsonb_build_object(
            'removed_user_id', p_user_id,
            'removed_by', v_caller_id,
            'reason', p_reason,
            'handle_items', p_handle_pending_items
        ),
        p_user_id
    );
END;
$$;
