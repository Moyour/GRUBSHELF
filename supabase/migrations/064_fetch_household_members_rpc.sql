-- Migration 064: Add RPC to fetch household members (bypasses RLS)
-- 
-- PROBLEM: fetchMembers() queries users table directly and is blocked by RLS
-- after sign-in when session isn't fully established.
--
-- SOLUTION: Create SECURITY DEFINER RPC that bypasses RLS

CREATE OR REPLACE FUNCTION public.fetch_household_members(p_household_id UUID)
RETURNS SETOF users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Verify caller has access to this household
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE user_id = auth.uid() 
        AND household_id = p_household_id
    ) THEN
        RAISE EXCEPTION 'Not a member of this household';
    END IF;
    
    -- Return all members of the household
    RETURN QUERY 
    SELECT * FROM users 
    WHERE household_id = p_household_id
    ORDER BY created_at ASC;
END;
$$;

COMMENT ON FUNCTION public.fetch_household_members(UUID) IS 
'Fetches all members of a household. Bypasses RLS using SECURITY DEFINER. Verifies caller is a member before returning data.';
