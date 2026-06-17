-- RPC function to check which provider (apple, google, email) a user signed up with.
-- This is used to guide users appropriately in the password reset flow.
-- Users who signed in with Apple/Google should not reset passwords; they should use OAuth.

CREATE OR REPLACE FUNCTION public.check_user_signin_provider(
    p_email TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_provider TEXT;
BEGIN
    -- First, find the user_id from auth.users by email
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = p_email
    LIMIT 1;
    
    -- If user doesn't exist, return 'email' (allow password reset attempt - Supabase will handle)
    IF v_user_id IS NULL THEN
        RETURN 'email';
    END IF;
    
    -- Check auth.identities to see which provider they used
    -- Priority: apple > google > email (if user has multiple, we show the OAuth one)
    SELECT provider INTO v_provider
    FROM auth.identities
    WHERE user_id = v_user_id
    ORDER BY 
        CASE provider
            WHEN 'apple' THEN 1
            WHEN 'google' THEN 2
            WHEN 'email' THEN 3
            ELSE 4
        END
    LIMIT 1;
    
    -- Return the provider or default to 'email'
    RETURN COALESCE(v_provider, 'email');
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.check_user_signin_provider(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_user_signin_provider(TEXT) TO anon;
