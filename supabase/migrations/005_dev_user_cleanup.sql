-- Cleanup function: removes the dev user from auth so sign-up can recreate it properly.
-- Also removes any stale rows in public.users / households left behind.
-- Called via: client.rpc("delete_dev_user")

CREATE OR REPLACE FUNCTION public.delete_dev_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    dev_uid UUID;
BEGIN
    SELECT id INTO dev_uid FROM auth.users WHERE email = 'dev@grubshelf.test';
    IF dev_uid IS NULL THEN
        RETURN;
    END IF;

    DELETE FROM auth.identities WHERE user_id = dev_uid;
    -- CASCADE from auth.users will remove public.users row automatically
    DELETE FROM auth.users WHERE id = dev_uid;
END;
$$;

-- Clean up the currently broken dev user right away
SELECT public.delete_dev_user();
