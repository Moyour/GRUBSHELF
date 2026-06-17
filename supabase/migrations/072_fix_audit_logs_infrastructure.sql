-- Hotfix: recreate the audit_logs table + log_audit_event() function on the
-- live project. Migrations 020 (audit_logs) and 045 (enhanced_audit_logs) are
-- recorded as applied in supabase_migrations.schema_migrations, but neither
-- the table nor the function actually exist (same drift pattern as 071 for
-- pantry_items.storage_location/photo_path).
--
-- Symptom: any approve/reject RPC (approve_pantry_item, reject_pantry_item,
-- approve_shopping_item, reject_shopping_item) fails with
--   42883: function "public.log_audit_event" does not exist
-- which surfaces to the iOS client as "Couldn't approve".
--
-- All operations are idempotent: IF NOT EXISTS, OR REPLACE, DROP POLICY IF
-- EXISTS / CREATE POLICY. Safe to re-run.

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

ALTER TABLE public.audit_logs
    ADD COLUMN IF NOT EXISTS performed_by UUID REFERENCES public.users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS affected_user UUID REFERENCES public.users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS old_value JSONB,
    ADD COLUMN IF NOT EXISTS new_value JSONB,
    ADD COLUMN IF NOT EXISTS ip_address TEXT;

CREATE INDEX IF NOT EXISTS idx_audit_logs_household
    ON public.audit_logs (household_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_affected_user
    ON public.audit_logs (affected_user, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action
    ON public.audit_logs (action, created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_logs_select ON public.audit_logs;
CREATE POLICY audit_logs_select ON public.audit_logs
    FOR SELECT
    USING (
        household_id IN (
            SELECT household_id FROM public.users WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS audit_logs_no_direct_insert ON public.audit_logs;
CREATE POLICY audit_logs_no_direct_insert ON public.audit_logs
    FOR INSERT
    WITH CHECK (false);

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
SET search_path = public, pg_catalog
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

GRANT EXECUTE ON FUNCTION public.log_audit_event(TEXT, TEXT, UUID, JSONB, UUID, JSONB, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
