-- GrubShelf Migration 074: Restrict invites and shopping list mutations to admins/owners

-- Restore admin/owner-only household invites (reverses migration 032 member invites)
CREATE OR REPLACE FUNCTION public.create_household_invite(
    p_household_id UUID,
    p_invited_email TEXT,
    p_invited_by UUID
)
RETURNS SETOF household_invites
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_household UUID;
    v_member_count INT;
    v_existing_member BOOLEAN;
    v_existing_invite BOOLEAN;
BEGIN
    IF NOT check_rate_limit('create_invite', 5, 60) THEN
        RAISE EXCEPTION 'Invite rate limit exceeded. Try again later';
    END IF;

    SELECT household_id INTO v_caller_household
    FROM users WHERE user_id = auth.uid();

    IF v_caller_household IS NULL OR v_caller_household != p_household_id THEN
        RAISE EXCEPTION 'You are not a member of this household';
    END IF;

    IF NOT (is_household_admin() OR is_household_owner()) THEN
        RAISE EXCEPTION 'Only household admins can invite members';
    END IF;

    SELECT COUNT(*) INTO v_member_count
    FROM users WHERE household_id = p_household_id;

    IF v_member_count >= 20 THEN
        RAISE EXCEPTION 'Household has reached the maximum of 20 members';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM users
        WHERE household_id = p_household_id
          AND LOWER(email) = LOWER(p_invited_email)
    ) INTO v_existing_member;

    IF v_existing_member THEN
        RAISE EXCEPTION 'This person is already a member of your household';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM household_invites
        WHERE household_id = p_household_id
          AND invited_email = LOWER(p_invited_email)
          AND status = 'pending'
          AND expires_at > now()
    ) INTO v_existing_invite;

    IF v_existing_invite THEN
        RAISE EXCEPTION 'An invite has already been sent to this email';
    END IF;

    INSERT INTO household_invites (household_id, invited_email, invited_by, status, created_at, expires_at)
    VALUES (p_household_id, LOWER(p_invited_email), p_invited_by, 'pending', now(), now() + interval '7 days');

    PERFORM log_audit_event(
        'invite_created',
        'household_invites',
        NULL,
        jsonb_build_object('invited_email', LOWER(p_invited_email), 'household_id', p_household_id)
    );

    RETURN QUERY
    SELECT * FROM household_invites
    WHERE household_id = p_household_id
      AND invited_email = LOWER(p_invited_email)
      AND status = 'pending'
    ORDER BY created_at DESC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.create_household_invite IS
'Creates a pending household invite. Only household admins or the owner may invite.';

-- Shopping lists: members can read; admins/owners can mutate
DROP POLICY IF EXISTS "Members can insert lists" ON shopping_lists;
DROP POLICY IF EXISTS "Members can update lists" ON shopping_lists;
DROP POLICY IF EXISTS "Members can delete lists" ON shopping_lists;

CREATE POLICY "Admins can insert lists"
    ON shopping_lists FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND (is_household_admin() OR is_household_owner())
    );

CREATE POLICY "Admins can update lists"
    ON shopping_lists FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND (is_household_admin() OR is_household_owner())
    );

CREATE POLICY "Admins can delete lists"
    ON shopping_lists FOR DELETE
    USING (
        household_id = get_my_household_id()
        AND (is_household_admin() OR is_household_owner())
    );
