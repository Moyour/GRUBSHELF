-- ============================================================
-- AUTO-CREATE public.users row when an auth user is created.
-- This is the standard Supabase pattern. It runs as a trigger
-- on auth.users so the row is GUARANTEED to exist before any
-- client code executes.
-- ============================================================

-- 1. Trigger function: fires after INSERT on auth.users
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (user_id, name, email, role, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
        COALESCE(NEW.email, ''),
        'member',
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- 2. Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- 3. Backfill: create public.users rows for any auth users that are missing one
INSERT INTO public.users (user_id, name, email, role, created_at, updated_at)
SELECT
    au.id,
    COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User'),
    COALESCE(au.email, ''),
    'member',
    NOW(),
    NOW()
FROM auth.users au
LEFT JOIN public.users pu ON pu.user_id = au.id
WHERE pu.user_id IS NULL;

-- 4. Keep the ensure_user_profile RPC for household linking
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
