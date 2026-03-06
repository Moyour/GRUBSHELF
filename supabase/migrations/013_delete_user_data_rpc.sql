-- Migration 013: Create delete_user_data RPC function
-- Called by the app when a user requests account deletion

CREATE OR REPLACE FUNCTION public.delete_user_data(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
    v_member_count INT;
BEGIN
    -- Get the user's household
    SELECT household_id INTO v_household_id
    FROM public.users
    WHERE user_id = p_user_id;

    -- Delete user's shopping items
    DELETE FROM public.shopping_items WHERE created_by = p_user_id;

    -- Delete user's shopping lists
    DELETE FROM public.shopping_lists WHERE created_by = p_user_id;

    -- Delete user's transactions
    DELETE FROM public.transactions WHERE household_id = v_household_id
        AND item_id IN (SELECT item_id FROM public.pantry_items WHERE created_by = p_user_id);

    -- Delete user's pantry items
    DELETE FROM public.pantry_items WHERE created_by = p_user_id;

    -- Delete invites created by this user
    DELETE FROM public.household_invites WHERE invited_by = p_user_id;

    -- Check if user is the last member of their household
    IF v_household_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_member_count
        FROM public.users
        WHERE household_id = v_household_id AND user_id != p_user_id;

        -- If no other members, delete the household (cascades remaining data)
        IF v_member_count = 0 THEN
            DELETE FROM public.households WHERE household_id = v_household_id;
        END IF;
    END IF;

    -- Delete the user profile row
    DELETE FROM public.users WHERE user_id = p_user_id;

    -- Delete the auth user (triggers cascade)
    DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;
