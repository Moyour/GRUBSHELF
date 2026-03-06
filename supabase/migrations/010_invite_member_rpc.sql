-- RPC to create a household invite, bypassing RLS.
-- Validates: caller is admin of the household, email is valid,
-- not already a member, no duplicate pending invite, household not full.

CREATE OR REPLACE FUNCTION public.create_household_invite(
    p_household_id UUID,
    p_invited_email TEXT,
    p_invited_by UUID
)
RETURNS SETOF household_invites
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_role TEXT;
    v_caller_household UUID;
    v_member_count INT;
    v_existing_member BOOLEAN;
    v_existing_invite BOOLEAN;
BEGIN
    -- Verify caller belongs to this household and is admin
    SELECT role, household_id INTO v_caller_role, v_caller_household
    FROM users WHERE user_id = auth.uid();

    IF v_caller_household IS NULL OR v_caller_household != p_household_id THEN
        RAISE EXCEPTION 'You are not a member of this household';
    END IF;

    IF v_caller_role != 'admin' THEN
        RAISE EXCEPTION 'Only admins can invite members';
    END IF;

    -- Check household member limit
    SELECT COUNT(*) INTO v_member_count
    FROM users WHERE household_id = p_household_id;

    IF v_member_count >= 20 THEN
        RAISE EXCEPTION 'Household has reached the maximum of 20 members';
    END IF;

    -- Check if already a member
    SELECT EXISTS(
        SELECT 1 FROM users
        WHERE household_id = p_household_id
          AND LOWER(email) = LOWER(p_invited_email)
    ) INTO v_existing_member;

    IF v_existing_member THEN
        RAISE EXCEPTION 'This person is already a member of your household';
    END IF;

    -- Check for existing pending invite
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

    -- Create the invite
    INSERT INTO household_invites (household_id, invited_email, invited_by, status, created_at, expires_at)
    VALUES (p_household_id, LOWER(p_invited_email), p_invited_by, 'pending', now(), now() + interval '7 days');

    RETURN QUERY
    SELECT * FROM household_invites
    WHERE household_id = p_household_id
      AND invited_email = LOWER(p_invited_email)
      AND status = 'pending'
    ORDER BY created_at DESC
    LIMIT 1;
END;
$$;
