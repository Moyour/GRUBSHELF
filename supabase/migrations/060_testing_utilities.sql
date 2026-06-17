-- GrubShelf Migration 060: Development testing utilities (guarded)

CREATE OR REPLACE FUNCTION create_test_household_with_members(
    p_household_name TEXT,
    p_member_count INTEGER DEFAULT 5
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    IF current_setting('app.environment', TRUE) IS DISTINCT FROM 'development' THEN
        RAISE EXCEPTION 'create_test_household_with_members is only available in development';
    END IF;

    IF p_member_count < 1 OR p_member_count > 20 THEN
        RAISE EXCEPTION 'member_count must be between 1 and 20';
    END IF;

    INSERT INTO households (name)
    VALUES (p_household_name)
    RETURNING household_id INTO v_household_id;

    RETURN v_household_id;
END;
$$;

COMMENT ON FUNCTION create_test_household_with_members IS
'Creates an empty test household. Set app.environment=development to use. Auth users must be linked separately.';
