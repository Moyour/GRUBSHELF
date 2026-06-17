-- GrubShelf Migration 054: Category-specific approval rules

ALTER TABLE households
    ADD COLUMN IF NOT EXISTS category_approval_rules JSONB NOT NULL DEFAULT '{}'::JSONB;

CREATE OR REPLACE FUNCTION category_requires_approval(p_category TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rules JSONB;
    v_value TEXT;
BEGIN
    SELECT category_approval_rules INTO v_rules
    FROM households
    WHERE household_id = get_my_household_id();

    IF v_rules IS NULL OR NOT (v_rules ? p_category) THEN
        RETURN TRUE;
    END IF;

    v_value := v_rules ->> p_category;
    RETURN COALESCE(v_value::BOOLEAN, TRUE);
END;
$$;

CREATE OR REPLACE FUNCTION set_category_approval_rule(
    p_category TEXT,
    p_requires_approval BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT (is_household_admin() OR is_household_owner()) THEN
        RAISE EXCEPTION 'Only admins can set category rules';
    END IF;

    UPDATE households
    SET category_approval_rules =
        COALESCE(category_approval_rules, '{}'::JSONB) ||
        jsonb_build_object(p_category, p_requires_approval)
    WHERE household_id = get_my_household_id();

    PERFORM log_audit_event(
        'category_approval_rule_set',
        'households',
        get_my_household_id(),
        jsonb_build_object('category', p_category, 'requires_approval', p_requires_approval)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION category_requires_approval(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION set_category_approval_rule(TEXT, BOOLEAN) TO authenticated;
