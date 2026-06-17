-- Migration 062: Fix RLS to allow invited users to see household name
-- 
-- PROBLEM: When a new user signs up after being invited, they can't see
-- the household they're being invited to because RLS blocks the read.
-- This prevents the invite from being found and accepted automatically.
--
-- SOLUTION: Add a new SELECT policy that allows users to read household
-- info if they have a pending/approved invite for that household.

-- Add new policy to allow reading household info when there's an invite
CREATE POLICY "Users can read households they are invited to"
    ON households FOR SELECT
    USING (
        household_id IN (
            SELECT household_id 
            FROM household_invites
            WHERE LOWER(invited_email) = LOWER((SELECT email FROM auth.users WHERE id = auth.uid()))
              AND status IN ('pending', 'approved')
              AND expires_at > NOW()
        )
    );

-- Comment explaining the policies
COMMENT ON POLICY "Users can read households they are invited to" ON households IS 
'Allows users to read basic household info (like name) when they have an active pending or approved invite. This is needed for the invite acceptance flow where users see which household they are joining.';
