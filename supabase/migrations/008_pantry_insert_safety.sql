-- ============================================================
-- BEFORE INSERT trigger on pantry_items: guarantees the
-- created_by user row exists in public.users before the
-- foreign key is checked. Pulls data from auth.users.
-- Also covers shopping_items for the same reason.
-- ============================================================

-- 1. Trigger function
CREATE OR REPLACE FUNCTION public.ensure_user_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE user_id = NEW.created_by) THEN
        INSERT INTO public.users (user_id, name, email, role, created_at, updated_at)
        SELECT
            NEW.created_by,
            COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User'),
            COALESCE(au.email, ''),
            'member',
            NOW(), NOW()
        FROM auth.users au
        WHERE au.id = NEW.created_by
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

-- 2. Attach to pantry_items
DROP TRIGGER IF EXISTS ensure_user_before_pantry ON pantry_items;
CREATE TRIGGER ensure_user_before_pantry
    BEFORE INSERT ON pantry_items
    FOR EACH ROW
    EXECUTE FUNCTION public.ensure_user_before_insert();

-- 3. Attach to shopping_items (same foreign key)
DROP TRIGGER IF EXISTS ensure_user_before_shopping ON shopping_items;
CREATE TRIGGER ensure_user_before_shopping
    BEFORE INSERT ON shopping_items
    FOR EACH ROW
    EXECUTE FUNCTION public.ensure_user_before_insert();

-- 4. Clean up orphaned public.users rows (old auth users that were deleted)
DELETE FROM public.users
WHERE user_id NOT IN (SELECT id FROM auth.users);

-- 5. Re-backfill any auth users missing a public.users row
INSERT INTO public.users (user_id, name, email, role, created_at, updated_at)
SELECT
    au.id,
    COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User'),
    COALESCE(au.email, ''),
    'member',
    NOW(), NOW()
FROM auth.users au
LEFT JOIN public.users pu ON pu.user_id = au.id
WHERE pu.user_id IS NULL;
