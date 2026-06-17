-- GrubShelf Migration 052: Custom per-member permissions

CREATE TABLE IF NOT EXISTS member_permissions (
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL CHECK (permission_key IN (
        'can_log_purchases',
        'can_manage_budget',
        'can_approve_items',
        'can_view_financial_data',
        'can_export_data',
        'can_manage_categories'
    )),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    granted_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, permission_key)
);

CREATE INDEX IF NOT EXISTS idx_member_permissions_user ON member_permissions(user_id);

ALTER TABLE member_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own permissions"
    ON member_permissions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Admins can read household member permissions"
    ON member_permissions FOR SELECT
    USING (
        user_id IN (
            SELECT user_id FROM users WHERE household_id = get_my_household_id()
        )
        AND is_household_admin()
    );

CREATE POLICY "No direct member_permissions insert"
    ON member_permissions FOR INSERT
    WITH CHECK (false);

CREATE POLICY "No direct member_permissions update"
    ON member_permissions FOR UPDATE
    USING (false);

CREATE POLICY "No direct member_permissions delete"
    ON member_permissions FOR DELETE
    USING (false);

CREATE OR REPLACE FUNCTION has_permission(
    p_user_id UUID,
    p_permission TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_perm BOOLEAN;
BEGIN
    SELECT (role = 'admin' OR is_owner) INTO v_has_perm
    FROM users WHERE user_id = p_user_id;

    IF COALESCE(v_has_perm, FALSE) THEN
        RETURN TRUE;
    END IF;

    SELECT enabled INTO v_has_perm
    FROM member_permissions
    WHERE user_id = p_user_id AND permission_key = p_permission;

    RETURN COALESCE(v_has_perm, FALSE);
END;
$$;

CREATE OR REPLACE FUNCTION grant_permission(
    p_user_id UUID,
    p_permission TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT (is_household_admin() OR is_household_owner()) THEN
        RAISE EXCEPTION 'Only admins can grant permissions';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE user_id = p_user_id AND household_id = get_my_household_id()
    ) THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    INSERT INTO member_permissions (user_id, permission_key, enabled, granted_by)
    VALUES (p_user_id, p_permission, TRUE, auth.uid())
    ON CONFLICT (user_id, permission_key) DO UPDATE
    SET enabled = TRUE, granted_by = auth.uid(), granted_at = NOW();

    PERFORM log_audit_event(
        'permission_granted',
        'member_permissions',
        NULL,
        jsonb_build_object('user_id', p_user_id, 'permission', p_permission)
    );
END;
$$;

CREATE OR REPLACE FUNCTION revoke_permission(
    p_user_id UUID,
    p_permission TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT (is_household_admin() OR is_household_owner()) THEN
        RAISE EXCEPTION 'Only admins can revoke permissions';
    END IF;

    DELETE FROM member_permissions
    WHERE user_id = p_user_id AND permission_key = p_permission;

    PERFORM log_audit_event(
        'permission_revoked',
        'member_permissions',
        NULL,
        jsonb_build_object('user_id', p_user_id, 'permission', p_permission)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION has_permission(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION grant_permission(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_permission(UUID, TEXT) TO authenticated;
