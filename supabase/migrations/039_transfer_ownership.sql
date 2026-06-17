-- GrubShelf Migration 039: Transfer household ownership

CREATE OR REPLACE FUNCTION public.transfer_ownership(
    p_new_owner_id UUID,
    p_confirmation_token TEXT DEFAULT NULL
)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_household_id UUID;
    v_new_owner_household UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT household_id INTO v_household_id
    FROM users
    WHERE user_id = v_caller_id AND is_owner = TRUE;

    IF v_household_id IS NULL THEN
        RAISE EXCEPTION 'Only the household owner can transfer ownership';
    END IF;

    SELECT household_id INTO v_new_owner_household
    FROM users
    WHERE user_id = p_new_owner_id;

    IF v_new_owner_household IS NULL OR v_new_owner_household != v_household_id THEN
        RAISE EXCEPTION 'New owner must be a member of your household';
    END IF;

    IF p_new_owner_id = v_caller_id THEN
        RAISE EXCEPTION 'Cannot transfer ownership to yourself';
    END IF;

    UPDATE users
    SET is_owner = FALSE, updated_at = NOW()
    WHERE user_id = v_caller_id;

    UPDATE users
    SET is_owner = TRUE, role = 'admin', updated_at = NOW()
    WHERE user_id = p_new_owner_id;

    PERFORM log_audit_event(
        'ownership_transferred',
        'users',
        p_new_owner_id,
        jsonb_build_object(
            'from_user_id', v_caller_id,
            'to_user_id', p_new_owner_id,
            'household_id', v_household_id
        )
    );

    RETURN QUERY SELECT * FROM users WHERE user_id = p_new_owner_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_ownership(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.transfer_ownership IS
'Transfers household ownership to another member. Caller must be current owner.';
