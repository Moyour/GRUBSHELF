-- Hotfix: consolidated schema-drift repair. Every object below is recorded
-- as already-applied in supabase_migrations.schema_migrations on the live
-- project, but is actually missing from the database — the same pattern as
-- migrations 071 and 072.
--
-- Identified by sweeping every local migrations/[0-9]*.sql against
-- information_schema, pg_proc, pg_constraint, pg_trigger, pg_matviews on
-- the live project dpsyrzffwpfrsrsmsidm.
--
-- Re-applies the missing parts of:
--   012_shopping_items_transferred         (shopping_lists.transferred)
--   019_household_member_limit_trigger     (function + trigger)
--   022_household_barcode_labels           (table + index + trigger + RLS)
--   039_transfer_ownership                 (function)
--   041_owner_only_role_changes            (function + role constraint)
--   047_invite_approval_system             (columns + status constraint + RPCs)
--   059_pending_counts_view                (materialized view + refresh fns + triggers)
--
-- All operations are idempotent: IF NOT EXISTS / OR REPLACE / DROP IF EXISTS
-- before CREATE. Safe to re-run.

-- ============================================================
-- 012: shopping_lists.transferred
-- ============================================================

ALTER TABLE public.shopping_lists
    ADD COLUMN IF NOT EXISTS transferred BOOLEAN NOT NULL DEFAULT false;

-- ============================================================
-- 019: household member limit (function + trigger)
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_household_member_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $func$
DECLARE
    v_member_count INT;
BEGIN
    IF NEW.household_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_member_count
        FROM public.users
        WHERE household_id = NEW.household_id;

        IF v_member_count >= 20 THEN
            RAISE EXCEPTION 'Household has reached the maximum of 20 members';
        END IF;
    END IF;

    RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS enforce_household_member_limit ON public.users;
CREATE TRIGGER enforce_household_member_limit
    BEFORE INSERT OR UPDATE OF household_id ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.check_household_member_limit();

-- ============================================================
-- 022: household_barcode_labels (table + index + trigger + RLS)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.household_barcode_labels (
    household_id UUID NOT NULL REFERENCES public.households(household_id) ON DELETE CASCADE,
    barcode TEXT NOT NULL CHECK (
        char_length(barcode) BETWEEN 8 AND 14
        AND barcode ~ '^[0-9]+$'
    ),
    display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 120),
    category TEXT NOT NULL CHECK (char_length(category) BETWEEN 1 AND 40),
    catalog_item_id UUID REFERENCES public.grocery_catalog(catalog_item_id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (household_id, barcode)
);

CREATE INDEX IF NOT EXISTS idx_household_barcode_labels_household
    ON public.household_barcode_labels (household_id);

DROP TRIGGER IF EXISTS set_updated_at_household_barcode_labels ON public.household_barcode_labels;
CREATE TRIGGER set_updated_at_household_barcode_labels
    BEFORE UPDATE ON public.household_barcode_labels
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.household_barcode_labels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can read household barcode labels" ON public.household_barcode_labels;
CREATE POLICY "Members can read household barcode labels"
    ON public.household_barcode_labels FOR SELECT
    USING (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can insert household barcode labels" ON public.household_barcode_labels;
CREATE POLICY "Members can insert household barcode labels"
    ON public.household_barcode_labels FOR INSERT
    WITH CHECK (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can update household barcode labels" ON public.household_barcode_labels;
CREATE POLICY "Members can update household barcode labels"
    ON public.household_barcode_labels FOR UPDATE
    USING (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can delete household barcode labels" ON public.household_barcode_labels;
CREATE POLICY "Members can delete household barcode labels"
    ON public.household_barcode_labels FOR DELETE
    USING (household_id = get_my_household_id());

-- ============================================================
-- 041: allow 'guest' in users.role (and prepare for change_user_role)
-- ============================================================

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
    CHECK (role IN ('admin', 'member', 'guest'));

-- ============================================================
-- 039: transfer_ownership
-- ============================================================

CREATE OR REPLACE FUNCTION public.transfer_ownership(
    p_new_owner_id UUID,
    p_confirmation_token TEXT DEFAULT NULL
)
RETURNS SETOF public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
DECLARE
    v_caller_id UUID;
    v_household_id UUID;
    v_new_owner_household UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT household_id INTO v_household_id
    FROM public.users
    WHERE user_id = v_caller_id AND is_owner = TRUE;

    IF v_household_id IS NULL THEN
        RAISE EXCEPTION 'Only the household owner can transfer ownership';
    END IF;

    SELECT household_id INTO v_new_owner_household
    FROM public.users
    WHERE user_id = p_new_owner_id;

    IF v_new_owner_household IS NULL OR v_new_owner_household != v_household_id THEN
        RAISE EXCEPTION 'New owner must be a member of your household';
    END IF;

    IF p_new_owner_id = v_caller_id THEN
        RAISE EXCEPTION 'Cannot transfer ownership to yourself';
    END IF;

    UPDATE public.users
    SET is_owner = FALSE, updated_at = NOW()
    WHERE user_id = v_caller_id;

    UPDATE public.users
    SET is_owner = TRUE, role = 'admin', updated_at = NOW()
    WHERE user_id = p_new_owner_id;

    PERFORM log_audit_event(
        'ownership_transferred',
        'users',
        p_new_owner_id,
        jsonb_build_object(
            'from_user_id', v_caller_id,
            'to_user_id', p_new_owner_id,
            'household_id', v_household_id
        )
    );

    RETURN QUERY SELECT * FROM public.users WHERE user_id = p_new_owner_id;
END;
$func$;

GRANT EXECUTE ON FUNCTION public.transfer_ownership(UUID, TEXT) TO authenticated;

-- ============================================================
-- 041: change_user_role
-- ============================================================

CREATE OR REPLACE FUNCTION public.change_user_role(
    p_target_user_id UUID,
    p_new_role TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
DECLARE
    v_caller_id UUID;
    v_caller_is_owner BOOLEAN;
    v_caller_household UUID;
    v_target_household UUID;
    v_target_is_owner BOOLEAN;
    v_target_current_role TEXT;
    v_admin_count INT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_new_role NOT IN ('admin', 'member', 'guest') THEN
        RAISE EXCEPTION 'Invalid role: %', p_new_role;
    END IF;

    SELECT is_owner, household_id
    INTO v_caller_is_owner, v_caller_household
    FROM public.users WHERE user_id = v_caller_id;

    IF NOT COALESCE(v_caller_is_owner, FALSE) THEN
        RAISE EXCEPTION 'Only the household owner can change member roles';
    END IF;

    SELECT household_id, is_owner, role
    INTO v_target_household, v_target_is_owner, v_target_current_role
    FROM public.users WHERE user_id = p_target_user_id;

    IF v_target_household IS NULL OR v_target_household != v_caller_household THEN
        RAISE EXCEPTION 'Target user is not in your household';
    END IF;

    IF v_target_is_owner THEN
        RAISE EXCEPTION 'Cannot change owner role. Use transfer_ownership instead';
    END IF;

    IF p_new_role != 'admin' AND v_target_current_role = 'admin' THEN
        SELECT COUNT(*) INTO v_admin_count
        FROM public.users
        WHERE household_id = v_caller_household
          AND role = 'admin'
          AND user_id != p_target_user_id
          AND is_owner = FALSE;

        IF v_admin_count = 0 THEN
            RAISE EXCEPTION 'Cannot demote the last admin of a household';
        END IF;
    END IF;

    UPDATE public.users
    SET role = p_new_role, updated_at = NOW()
    WHERE user_id = p_target_user_id;

    PERFORM log_audit_event(
        'role_changed',
        'users',
        p_target_user_id,
        jsonb_build_object(
            'target_user_id', p_target_user_id,
            'old_role', v_target_current_role,
            'new_role', p_new_role,
            'changed_by', v_caller_id
        )
    );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.change_user_role(UUID, TEXT) TO authenticated;

-- ============================================================
-- 047: invite approval workflow (columns + status constraint + RPCs)
-- ============================================================

ALTER TABLE public.household_invites
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.household_invites DROP CONSTRAINT IF EXISTS household_invites_status_check;
ALTER TABLE public.household_invites ADD CONSTRAINT household_invites_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'accepted', 'cancelled', 'expired'));

CREATE OR REPLACE FUNCTION public.approve_household_invite(p_invite_id UUID)
RETURNS SETOF public.household_invites
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
DECLARE
    v_household_id UUID;
    v_inviter_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve invites';
    END IF;

    SELECT household_id, invited_by
    INTO v_household_id, v_inviter_id
    FROM public.household_invites
    WHERE invite_id = p_invite_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Invite not found or access denied';
    END IF;

    IF v_inviter_id IS NOT NULL AND v_inviter_id != auth.uid() THEN
        PERFORM create_notification(
            v_inviter_id,
            'invite_approved',
            'Invite Approved',
            'Your household invite has been approved by an admin',
            jsonb_build_object('invite_id', p_invite_id)
        );
    END IF;

    PERFORM log_audit_event(
        'invite_approved',
        'household_invites',
        p_invite_id,
        jsonb_build_object('approved_by', auth.uid())
    );

    RETURN QUERY
    UPDATE public.household_invites
    SET status = 'approved', approved_by = auth.uid(), approved_at = NOW()
    WHERE invite_id = p_invite_id AND status = 'pending'
    RETURNING *;
END;
$func$;

CREATE OR REPLACE FUNCTION public.reject_household_invite(
    p_invite_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS SETOF public.household_invites
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
DECLARE
    v_household_id UUID;
    v_inviter_id UUID;
    v_body TEXT;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject invites';
    END IF;

    SELECT household_id, invited_by
    INTO v_household_id, v_inviter_id
    FROM public.household_invites
    WHERE invite_id = p_invite_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Invite not found or access denied';
    END IF;

    v_body := 'Your household invite was rejected';
    IF p_reason IS NOT NULL AND char_length(trim(p_reason)) > 0 THEN
        v_body := v_body || ': ' || p_reason;
    END IF;

    IF v_inviter_id IS NOT NULL AND v_inviter_id != auth.uid() THEN
        PERFORM create_notification(
            v_inviter_id,
            'invite_rejected',
            'Invite Rejected',
            v_body,
            jsonb_build_object('invite_id', p_invite_id, 'reason', p_reason)
        );
    END IF;

    PERFORM log_audit_event(
        'invite_rejected',
        'household_invites',
        p_invite_id,
        jsonb_build_object('rejected_by', auth.uid(), 'reason', p_reason)
    );

    RETURN QUERY
    UPDATE public.household_invites
    SET status = 'rejected', approved_by = auth.uid(), approved_at = NOW(), rejection_reason = p_reason
    WHERE invite_id = p_invite_id AND status = 'pending'
    RETURNING *;
END;
$func$;

GRANT EXECUTE ON FUNCTION public.approve_household_invite(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_household_invite(UUID, TEXT) TO authenticated;

-- ============================================================
-- 059: pending_approval_counts materialized view + refresh triggers
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS public.pending_approval_counts AS
SELECT
    household_id,
    COUNT(*) FILTER (WHERE source = 'pantry')::INTEGER AS pending_pantry_count,
    COUNT(*) FILTER (WHERE source = 'shopping')::INTEGER AS pending_shopping_count,
    MAX(latest_pending_at) AS latest_pending_at
FROM (
    SELECT household_id, 'pantry'::TEXT AS source, created_at AS latest_pending_at
    FROM public.pantry_items
    WHERE approval_status = 'pending'

    UNION ALL

    SELECT household_id, 'shopping'::TEXT AS source, created_at AS latest_pending_at
    FROM public.shopping_items
    WHERE approval_status = 'pending'
) combined
GROUP BY household_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_approval_counts_household
    ON public.pending_approval_counts (household_id);

CREATE OR REPLACE FUNCTION public.refresh_pending_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.pending_approval_counts;
EXCEPTION
    WHEN OTHERS THEN
        REFRESH MATERIALIZED VIEW public.pending_approval_counts;
END;
$func$;

CREATE OR REPLACE FUNCTION public.trigger_refresh_pending_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $func$
BEGIN
    PERFORM refresh_pending_counts();
    RETURN NULL;
END;
$func$;

DROP TRIGGER IF EXISTS refresh_pending_counts_pantry ON public.pantry_items;
CREATE TRIGGER refresh_pending_counts_pantry
    AFTER INSERT OR UPDATE OR DELETE ON public.pantry_items
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.trigger_refresh_pending_counts();

DROP TRIGGER IF EXISTS refresh_pending_counts_shopping ON public.shopping_items;
CREATE TRIGGER refresh_pending_counts_shopping
    AFTER INSERT OR UPDATE OR DELETE ON public.shopping_items
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.trigger_refresh_pending_counts();

SELECT public.refresh_pending_counts();

GRANT EXECUTE ON FUNCTION public.refresh_pending_counts() TO authenticated;

NOTIFY pgrst, 'reload schema';
