-- GrubShelf Migration 056: Rate limiting for invites and sensitive actions

CREATE TABLE IF NOT EXISTS rate_limits (
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    action_count INTEGER NOT NULL DEFAULT 1,
    window_start TIMESTAMPTZ NOT NULL DEFAULT date_trunc('hour', NOW()),
    PRIMARY KEY (user_id, action_type, window_start)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action
    ON rate_limits (user_id, action_type, window_start DESC);

ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "No direct rate_limits access"
    ON rate_limits FOR ALL
    USING (false)
    WITH CHECK (false);

CREATE OR REPLACE FUNCTION check_rate_limit(
    p_action_type TEXT,
    p_max_count INTEGER,
    p_window_minutes INTEGER DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_window_start TIMESTAMPTZ;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_window_minutes <= 0 THEN
        RAISE EXCEPTION 'window_minutes must be positive';
    END IF;

    v_window_start := date_trunc('hour', NOW());

    SELECT action_count INTO v_count
    FROM rate_limits
    WHERE user_id = v_user_id
      AND action_type = p_action_type
      AND window_start = v_window_start;

    IF v_count IS NULL THEN
        INSERT INTO rate_limits (user_id, action_type, action_count, window_start)
        VALUES (v_user_id, p_action_type, 1, v_window_start);
        RETURN TRUE;
    ELSIF v_count < p_max_count THEN
        UPDATE rate_limits
        SET action_count = action_count + 1
        WHERE user_id = v_user_id
          AND action_type = p_action_type
          AND window_start = v_window_start;
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

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

GRANT EXECUTE ON FUNCTION check_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated;
