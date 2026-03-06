-- RPC function to ensure a user row exists in public.users.
-- Uses SECURITY DEFINER to bypass RLS, since the user row must be
-- created before any RLS policy referencing it can evaluate.

CREATE OR REPLACE FUNCTION public.ensure_user_profile(
    p_user_id UUID,
    p_name TEXT,
    p_email TEXT,
    p_household_id UUID DEFAULT NULL,
    p_role TEXT DEFAULT 'member'
)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO users (user_id, name, email, household_id, role, created_at, updated_at)
    VALUES (p_user_id, p_name, p_email, p_household_id, p_role, NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        name = COALESCE(NULLIF(users.name, ''), EXCLUDED.name),
        household_id = COALESCE(users.household_id, EXCLUDED.household_id),
        role = CASE WHEN EXCLUDED.role = 'admin' THEN 'admin' ELSE users.role END,
        updated_at = NOW();

    RETURN QUERY SELECT * FROM users WHERE user_id = p_user_id;
END;
$$;
