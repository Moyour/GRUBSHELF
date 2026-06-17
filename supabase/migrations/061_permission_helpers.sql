-- GrubShelf Migration 061: Consolidated permission helper RPCs for clients

CREATE OR REPLACE FUNCTION get_my_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user users%ROWTYPE;
    v_perms JSONB;
BEGIN
    SELECT * INTO v_user FROM users WHERE user_id = auth.uid();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found';
    END IF;

    SELECT COALESCE(jsonb_object_agg(permission_key, enabled), '{}'::JSONB)
    INTO v_perms
    FROM member_permissions
    WHERE user_id = auth.uid();

    RETURN jsonb_build_object(
        'user_id', v_user.user_id,
        'role', v_user.role,
        'is_owner', COALESCE(v_user.is_owner, FALSE),
        'is_admin', v_user.role = 'admin',
        'can_modify_budget', COALESCE(v_user.can_modify_budget, FALSE),
        'can_approve_up_to_amount', COALESCE(v_user.can_approve_up_to_amount, 0),
        'custom_permissions', COALESCE(v_perms, '{}'::JSONB),
        'can_delete_household', COALESCE(v_user.is_owner, FALSE),
        'can_change_roles', COALESCE(v_user.is_owner, FALSE),
        'can_transfer_ownership', COALESCE(v_user.is_owner, FALSE),
        'can_remove_members', COALESCE(v_user.is_owner, FALSE) OR v_user.role = 'admin',
        'can_approve_items', v_user.role = 'admin',
        'can_add_items_directly', v_user.role = 'admin'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_permissions() TO authenticated;
