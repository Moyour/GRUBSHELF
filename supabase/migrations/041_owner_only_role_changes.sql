-- GrubShelf Migration 041: Owner-only role changes (includes guest role)

CREATE OR REPLACE FUNCTION public.change_user_role(
    p_target_user_id UUID,
    p_new_role TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_is_owner BOOLEAN;
    v_caller_household UUID;
    v_target_household UUID;
    v_target_is_owner BOOLEAN;
    v_target_current_role TEXT;
    v_admin_count INT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_new_role NOT IN ('admin', 'member', 'guest') THEN
        RAISE EXCEPTION 'Invalid role: %', p_new_role;
    END IF;

    SELECT is_owner, household_id
    INTO v_caller_is_owner, v_caller_household
    FROM users WHERE user_id = v_caller_id;

    IF NOT COALESCE(v_caller_is_owner, FALSE) THEN
        RAISE EXCEPTION 'Only the household owner can change member roles';
    END IF;

    SELECT household_id, is_owner, role
    INTO v_target_household, v_target_is_owner, v_target_current_role
    FROM users WHERE user_id = p_target_user_id;

    IF v_target_household IS NULL OR v_target_household != v_caller_household THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    IF v_target_is_owner THEN
        RAISE EXCEPTION 'Cannot change owner role. Use transfer_ownership instead';
    END IF;

    IF p_new_role != 'admin' AND v_target_current_role = 'admin' THEN
        SELECT COUNT(*) INTO v_admin_count
        FROM users
        WHERE household_id = v_caller_household
          AND role = 'admin'
          AND user_id != p_target_user_id
          AND is_owner = FALSE;

        IF v_admin_count = 0 THEN
            RAISE EXCEPTION 'Cannot demote the last admin of a household';
        END IF;
    END IF;

    UPDATE users
    SET role = p_new_role, updated_at = NOW()
    WHERE user_id = p_target_user_id;

    PERFORM log_audit_event(
        'role_changed',
        'users',
        p_target_user_id,
        jsonb_build_object(
            'target_user_id', p_target_user_id,
            'old_role', v_target_current_role,
            'new_role', p_new_role,
            'changed_by', v_caller_id
        )
    );
END;
$$;

-- Allow guest role in users table
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
    CHECK (role IN ('admin', 'member', 'guest'));

GRANT EXECUTE ON FUNCTION public.change_user_role(UUID, TEXT) TO authenticated;
