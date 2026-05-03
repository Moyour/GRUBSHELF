-- Migration 020: Audit logging table and RPC
-- Records security-relevant actions (role changes, member removal, invites, account deletion)

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    household_id UUID,
    action TEXT NOT NULL,
    target_entity TEXT,
    target_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for querying by household
CREATE INDEX IF NOT EXISTS idx_audit_logs_household ON public.audit_logs (household_id, created_at DESC);

-- RLS: users can read their own household's logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_logs_select ON public.audit_logs
    FOR SELECT
    USING (
        household_id IN (
            SELECT household_id FROM public.users WHERE user_id = auth.uid()
        )
    );

-- No direct INSERT/UPDATE/DELETE for regular users — use the RPC below
CREATE POLICY audit_logs_no_direct_insert ON public.audit_logs
    FOR INSERT
    WITH CHECK (false);

-- SECURITY DEFINER RPC to insert audit log entries
CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_action TEXT,
    p_target_entity TEXT DEFAULT NULL,
    p_target_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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

    INSERT INTO public.audit_logs (user_id, household_id, action, target_entity, target_id, metadata)
    VALUES (v_user_id, v_household_id, p_action, p_target_entity, p_target_id, p_metadata);
END;
$$;
