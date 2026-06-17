-- GrubShelf Migration 036: Approval RPCs for pantry and shopping items

-- Approve pantry item (admin only)
CREATE OR REPLACE FUNCTION approve_pantry_item(p_item_id UUID)
RETURNS SETOF pantry_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    SELECT household_id INTO v_household_id
    FROM pantry_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    RETURN QUERY
    UPDATE pantry_items
    SET
        approval_status = 'approved',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = NULL,
        updated_at = now()
    WHERE item_id = p_item_id
    RETURNING *;
END;
$$;

-- Reject pantry item (admin only)
CREATE OR REPLACE FUNCTION reject_pantry_item(
    p_item_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS SETOF pantry_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject items';
    END IF;

    SELECT household_id INTO v_household_id
    FROM pantry_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    RETURN QUERY
    UPDATE pantry_items
    SET
        approval_status = 'rejected',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = p_reason,
        updated_at = now()
    WHERE item_id = p_item_id
    RETURNING *;
END;
$$;

-- Approve shopping item (admin only)
CREATE OR REPLACE FUNCTION approve_shopping_item(p_item_id UUID)
RETURNS SETOF shopping_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    SELECT household_id INTO v_household_id
    FROM shopping_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    RETURN QUERY
    UPDATE shopping_items
    SET
        approval_status = 'approved',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = NULL,
        updated_at = now()
    WHERE item_id = p_item_id
    RETURNING *;
END;
$$;

-- Reject shopping item (admin only)
CREATE OR REPLACE FUNCTION reject_shopping_item(
    p_item_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS SETOF shopping_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject items';
    END IF;

    SELECT household_id INTO v_household_id
    FROM shopping_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    RETURN QUERY
    UPDATE shopping_items
    SET
        approval_status = 'rejected',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = p_reason,
        updated_at = now()
    WHERE item_id = p_item_id
    RETURNING *;
END;
$$;

-- Pending approval counts for dashboard
CREATE OR REPLACE FUNCTION get_pending_approvals_count(p_household_id UUID)
RETURNS TABLE (
    pending_pantry_count INTEGER,
    pending_shopping_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_household_id IS DISTINCT FROM get_my_household_id() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::INTEGER FROM pantry_items
         WHERE household_id = p_household_id AND approval_status = 'pending'),
        (SELECT COUNT(*)::INTEGER FROM shopping_items
         WHERE household_id = p_household_id AND approval_status = 'pending');
END;
$$;

-- Bulk approve pantry items (admin only)
CREATE OR REPLACE FUNCTION bulk_approve_pantry_items(p_item_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    UPDATE pantry_items
    SET
        approval_status = 'approved',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = NULL,
        updated_at = now()
    WHERE
        item_id = ANY(p_item_ids)
        AND household_id = get_my_household_id()
        AND approval_status = 'pending';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- Bulk approve shopping items (admin only)
CREATE OR REPLACE FUNCTION bulk_approve_shopping_items(p_item_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    UPDATE shopping_items
    SET
        approval_status = 'approved',
        approved_by = auth.uid(),
        approved_at = now(),
        rejection_reason = NULL,
        updated_at = now()
    WHERE
        item_id = ANY(p_item_ids)
        AND household_id = get_my_household_id()
        AND approval_status = 'pending';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION approve_pantry_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_pantry_item(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_shopping_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_shopping_item(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_approvals_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_approve_pantry_items(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_approve_shopping_items(UUID[]) TO authenticated;
