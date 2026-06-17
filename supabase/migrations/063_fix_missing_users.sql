-- Migration 063: Fix missing users and add auto-creation trigger
-- 
-- PROBLEM: Users who sign up don't automatically get a row in public.users,
-- causing "permission denied for table users" because RLS can't find them.
--
-- SOLUTION:
-- 1. Backfill any auth users missing from public.users
-- 2. Create a trigger to auto-create public.users when auth.users signs up

-- Step 1: Backfill missing users from auth.users
INSERT INTO public.users (user_id, name, email, role, created_at, updated_at)
SELECT
    au.id,
    COALESCE(
        au.raw_user_meta_data->>'name',
        au.raw_user_meta_data->>'full_name',
        split_part(au.email, '@', 1),
        'User'
    ),
    au.email,
    'member',
    au.created_at,
    NOW()
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.users pu WHERE pu.user_id = au.id
)
ON CONFLICT (user_id) DO NOTHING;

-- Step 2: Create function to auto-create user on auth signup
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
        COALESCE(
            NEW.raw_user_meta_data->>'name',
            NEW.raw_user_meta_data->>'full_name',
            split_part(NEW.email, '@', 1),
            'User'
        ),
        NEW.email,
        'member',
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- Step 3: Create trigger on auth.users to auto-create public.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- Add helpful comment
COMMENT ON FUNCTION public.handle_new_auth_user() IS 
'Automatically creates a public.users row when a new user signs up in auth.users. This prevents "permission denied" errors from RLS policies that expect users to exist.';
