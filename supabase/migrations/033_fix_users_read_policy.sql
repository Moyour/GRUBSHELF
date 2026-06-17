-- Fix RLS policy to allow household members to see each other
-- Migration 033: Allow household members to read other members

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Users can read own row" ON users;

-- Create new policy: Users can read themselves AND other members of their household
CREATE POLICY "Users can read own household members"
    ON users FOR SELECT 
    USING (
        user_id = auth.uid() 
        OR household_id = (SELECT household_id FROM users WHERE user_id = auth.uid())
    );

-- Add comment explaining the policy
COMMENT ON POLICY "Users can read own household members" ON users IS 
'Allows users to read their own profile and all other members of their household. This enables viewing the member list, invites, and household management.';
