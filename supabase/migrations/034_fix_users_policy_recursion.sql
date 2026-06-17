-- Fix infinite recursion in users RLS policy
-- Migration 034: Use SECURITY DEFINER function to avoid recursion

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can read own household members" ON users;

-- Create new policy using the existing helper function that bypasses RLS
CREATE POLICY "Users can read own household members"
    ON users FOR SELECT 
    USING (
        user_id = auth.uid() 
        OR household_id = get_my_household_id()
    );

-- Add comment explaining the fix
COMMENT ON POLICY "Users can read own household members" ON users IS 
'Allows users to read their own profile and all other members of their household. Uses get_my_household_id() SECURITY DEFINER function to avoid infinite recursion.';
