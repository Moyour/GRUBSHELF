-- Migration 018: Fix role escalation in ensure_user_profile and add change_user_role RPC
--
-- 1. Remove p_role parameter from ensure_user_profile — new users always get 'member'
-- 2. On conflict, never update the role column
-- 3. Add a separate change_user_role RPC that requires caller to be admin of same household

-- Fix ensure_user_profile: hardcode 'member' for new users, never change role on conflict
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
        name = COALESCE(NULLIF(users.name, ''), EXCLUDED.name),
        household_id = COALESCE(users.household_id, EXCLUDED.household_id),
        updated_at = NOW();

    RETURN QUERY SELECT * FROM users WHERE user_id = p_user_id;
END;
$$;

-- New RPC: change_user_role
-- Requires caller to be admin of the same household as the target user.
-- Prevents demoting the last admin of a household.
CREATE OR REPLACE FUNCTION public.change_user_role(
    p_target_user_id UUID,
    p_new_role TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_household UUID;
    v_target_household UUID;
    v_admin_count INT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate role value
    IF p_new_role NOT IN ('admin', 'member') THEN
        RAISE EXCEPTION 'Invalid role: %', p_new_role;
    END IF;

    -- Get caller info
    SELECT role, household_id INTO v_caller_role, v_caller_household
    FROM public.users
    WHERE user_id = v_caller_id;

    IF v_caller_role != 'admin' THEN
        RAISE EXCEPTION 'Only admins can change roles';
    END IF;

    -- Get target household
    SELECT household_id INTO v_target_household
    FROM public.users
    WHERE user_id = p_target_user_id;

    IF v_target_household IS NULL OR v_target_household != v_caller_household THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    -- Prevent demoting the last admin
    IF p_new_role = 'member' THEN
        SELECT COUNT(*) INTO v_admin_count
        FROM public.users
        WHERE household_id = v_caller_household
          AND role = 'admin'
          AND user_id != p_target_user_id;

        IF v_admin_count = 0 THEN
            RAISE EXCEPTION 'Cannot demote the last admin of a household';
        END IF;
    END IF;

    UPDATE public.users
    SET role = p_new_role, updated_at = NOW()
    WHERE user_id = p_target_user_id;
END;
$$;
