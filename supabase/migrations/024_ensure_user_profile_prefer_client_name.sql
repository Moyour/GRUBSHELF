-- When a row already exists (e.g. created by handle_new_auth_user with email-local-part),
-- prefer the non-empty name passed from the client (onboarding / sign-up) over the placeholder.

CREATE OR REPLACE FUNCTION public.ensure_user_profile(
    p_user_id UUID,
    p_name TEXT,
    p_email TEXT,
    p_household_id UUID DEFAULT NULL
)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO users (user_id, name, email, household_id, role, created_at, updated_at)
    VALUES (p_user_id, p_name, p_email, p_household_id, 'member', NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        name = COALESCE(NULLIF(TRIM(EXCLUDED.name), ''), users.name),
        household_id = COALESCE(users.household_id, EXCLUDED.household_id),
        updated_at = NOW();

    RETURN QUERY SELECT * FROM users WHERE user_id = p_user_id;
END;
$$;
