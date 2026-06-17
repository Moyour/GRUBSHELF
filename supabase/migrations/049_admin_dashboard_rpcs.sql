-- GrubShelf Migration 049: Admin dashboard pending approvals query

CREATE OR REPLACE FUNCTION get_pending_items_for_approval()
RETURNS TABLE (
    item_type TEXT,
    item_id UUID,
    item_name TEXT,
    quantity DOUBLE PRECISION,
    unit TEXT,
    category TEXT,
    created_by_id UUID,
    created_by_name TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can view pending approvals';
    END IF;

    RETURN QUERY
    SELECT
        'pantry'::TEXT,
        p.item_id,
        p.name,
        p.quantity,
        p.unit,
        p.category,
        p.created_by,
        u.name,
        p.created_at
    FROM pantry_items p
    JOIN users u ON p.created_by = u.user_id
    WHERE p.household_id = get_my_household_id()
      AND p.approval_status = 'pending'

    UNION ALL

    SELECT
        'shopping'::TEXT,
        s.item_id,
        s.name,
        s.quantity,
        COALESCE(s.unit, 'pcs'),
        COALESCE(s.category, ''),
        s.created_by,
        u.name,
        s.created_at
    FROM shopping_items s
    JOIN users u ON s.created_by = u.user_id
    WHERE s.household_id = get_my_household_id()
      AND s.approval_status = 'pending'

    ORDER BY 9 ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pending_items_for_approval() TO authenticated;
