-- GrubShelf Migration 037: Owner / primary admin distinction

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_owner BOOLEAN NOT NULL DEFAULT FALSE;

-- Designate earliest admin per household as owner
UPDATE users u1
SET is_owner = TRUE
WHERE role = 'admin'
  AND household_id IS NOT NULL
  AND user_id = (
    SELECT u2.user_id
    FROM users u2
    WHERE u2.household_id = u1.household_id
      AND u2.role = 'admin'
    ORDER BY u2.created_at ASC
    LIMIT 1
  );

CREATE OR REPLACE FUNCTION is_household_owner()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(is_owner, FALSE)
    FROM users
    WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE INDEX IF NOT EXISTS idx_users_household_owner
    ON users (household_id, is_owner)
    WHERE is_owner = TRUE;

-- Household creator becomes admin + owner
CREATE OR REPLACE FUNCTION public.set_self_admin_for_household(p_household_id UUID)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    updated_count INT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.users
    SET role = 'admin',
        is_owner = TRUE,
        updated_at = NOW()
    WHERE user_id = auth.uid()
      AND household_id IS NOT NULL
      AND household_id = p_household_id;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count = 0 THEN
        RAISE EXCEPTION 'Cannot promote: not a member of this household';
    END IF;

    RETURN QUERY SELECT * FROM public.users WHERE user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION is_household_owner() TO authenticated;

COMMENT ON COLUMN users.is_owner IS
'Primary household owner (creator). Only one owner per household; transfer via transfer_ownership().';
