-- Lets the authenticated user become admin only when their users.household_id
-- already matches the given household (e.g. after ensure_user_profile links them).
-- Used by iOS after creating a household so the creator is admin without passing
-- invalid RPC arguments to ensure_user_profile.
--
-- Post-deploy (manual): if users report repeat household onboarding, check public.users
-- for NULL household_id and households with zero members (orphans from partial failures).

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
    SET role = 'admin', updated_at = NOW()
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

GRANT EXECUTE ON FUNCTION public.set_self_admin_for_household(UUID) TO authenticated;
