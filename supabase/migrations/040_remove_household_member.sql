-- GrubShelf Migration 040: Remove household member with permission checks

CREATE OR REPLACE FUNCTION public.remove_household_member(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
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
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT role, is_owner, household_id
    INTO v_caller_role, v_caller_is_owner, v_caller_household
    FROM users WHERE user_id = v_caller_id;

    SELECT role, is_owner, household_id
    INTO v_target_role, v_target_is_owner, v_target_household
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

    UPDATE users
    SET household_id = NULL, updated_at = NOW()
    WHERE user_id = p_user_id;

    PERFORM log_audit_event(
        'member_removed',
        'users',
        p_user_id,
        jsonb_build_object(
            'removed_user_id', p_user_id,
            'removed_by', v_caller_id,
            'reason', p_reason,
            'target_role', v_target_role
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_household_member(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.remove_household_member IS
'Owner can remove any non-owner member. Admins can remove members only.';
