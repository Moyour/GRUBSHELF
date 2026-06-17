-- GrubShelf Migration 053: Approval delegation limits

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS can_approve_up_to_amount DECIMAL(10,2) NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.set_approval_delegation(
    p_user_id UUID,
    p_max_amount DECIMAL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT is_household_owner() THEN
        RAISE EXCEPTION 'Only the household owner can set delegation limits';
    END IF;

    IF p_max_amount IS NULL OR p_max_amount < 0 THEN
        RAISE EXCEPTION 'Max amount must be zero or positive';
    END IF;

    UPDATE users
    SET can_approve_up_to_amount = p_max_amount, updated_at = NOW()
    WHERE user_id = p_user_id
      AND household_id = get_my_household_id();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    PERFORM log_audit_event(
        'delegation_set',
        'users',
        p_user_id,
        jsonb_build_object('user_id', p_user_id, 'max_amount', p_max_amount)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_approval_delegation(UUID, DECIMAL) TO authenticated;

COMMENT ON COLUMN users.can_approve_up_to_amount IS
'Optional max purchase amount a non-admin may self-approve when delegation is enabled in app logic.';
