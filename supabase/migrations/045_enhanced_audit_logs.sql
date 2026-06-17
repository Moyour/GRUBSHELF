-- GrubShelf Migration 045: Enhanced audit log columns and RPC

ALTER TABLE audit_logs
    ADD COLUMN IF NOT EXISTS performed_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS affected_user UUID REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS old_value JSONB,
    ADD COLUMN IF NOT EXISTS new_value JSONB,
    ADD COLUMN IF NOT EXISTS ip_address TEXT;

CREATE INDEX IF NOT EXISTS idx_audit_logs_affected_user
    ON audit_logs (affected_user, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action
    ON audit_logs (action, created_at DESC);

CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_action TEXT,
    p_target_entity TEXT DEFAULT NULL,
    p_target_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}',
    p_affected_user UUID DEFAULT NULL,
    p_old_value JSONB DEFAULT NULL,
    p_new_value JSONB DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_household_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT household_id INTO v_household_id
    FROM public.users
    WHERE user_id = v_user_id;

    INSERT INTO public.audit_logs (
        user_id,
        household_id,
        action,
        target_entity,
        target_id,
        metadata,
        performed_by,
        affected_user,
        old_value,
        new_value
    )
    VALUES (
        v_user_id,
        v_household_id,
        p_action,
        p_target_entity,
        p_target_id,
        p_metadata,
        v_user_id,
        p_affected_user,
        p_old_value,
        p_new_value
    );
END;
$$;
