-- GrubShelf Migration 048: Budget modification permissions

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS can_modify_budget BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE users
SET can_modify_budget = TRUE
WHERE role = 'admin' OR is_owner = TRUE;

CREATE OR REPLACE FUNCTION can_user_modify_budget()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(can_modify_budget, FALSE)
    FROM users
    WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

DROP POLICY IF EXISTS "Admins can update household" ON households;

CREATE POLICY "Users with permission can update household"
    ON households FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND (is_household_admin() OR can_user_modify_budget())
    );

CREATE OR REPLACE FUNCTION public.set_budget_permission(
    p_user_id UUID,
    p_can_modify BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT (is_household_admin() OR is_household_owner()) THEN
        RAISE EXCEPTION 'Only admins can manage budget permissions';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE user_id = p_user_id AND household_id = get_my_household_id()
    ) THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    UPDATE users
    SET can_modify_budget = p_can_modify, updated_at = NOW()
    WHERE user_id = p_user_id;

    PERFORM log_audit_event(
        'budget_permission_changed',
        'users',
        p_user_id,
        jsonb_build_object('can_modify_budget', p_can_modify)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION can_user_modify_budget() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_budget_permission(UUID, BOOLEAN) TO authenticated;
