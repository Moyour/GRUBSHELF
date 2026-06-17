-- GrubShelf Migration 050: Member activity statistics for admins

CREATE OR REPLACE FUNCTION get_member_activity_stats()
RETURNS TABLE (
    user_id UUID,
    user_name TEXT,
    user_role TEXT,
    is_owner BOOLEAN,
    items_added_30d INTEGER,
    items_pending INTEGER,
    items_approved INTEGER,
    items_rejected INTEGER,
    approval_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can view member stats';
    END IF;

    RETURN QUERY
    WITH stats AS (
        SELECT
            u.user_id AS uid,
            u.name AS uname,
            u.role AS urole,
            u.is_owner AS uowner,
            (
                (SELECT COUNT(*)::INTEGER FROM pantry_items p
                 WHERE p.created_by = u.user_id
                   AND p.created_at >= NOW() - INTERVAL '30 days')
                +
                (SELECT COUNT(*)::INTEGER FROM shopping_items s
                 WHERE s.created_by = u.user_id
                   AND s.created_at >= NOW() - INTERVAL '30 days')
            ) AS added_30d,
            (
                (SELECT COUNT(*)::INTEGER FROM pantry_items p
                 WHERE p.created_by = u.user_id AND p.approval_status = 'pending')
                +
                (SELECT COUNT(*)::INTEGER FROM shopping_items s
                 WHERE s.created_by = u.user_id AND s.approval_status = 'pending')
            ) AS pending_cnt,
            (
                (SELECT COUNT(*)::INTEGER FROM pantry_items p
                 WHERE p.created_by = u.user_id AND p.approval_status = 'approved')
                +
                (SELECT COUNT(*)::INTEGER FROM shopping_items s
                 WHERE s.created_by = u.user_id AND s.approval_status = 'approved')
            ) AS approved_cnt,
            (
                (SELECT COUNT(*)::INTEGER FROM pantry_items p
                 WHERE p.created_by = u.user_id AND p.approval_status = 'rejected')
                +
                (SELECT COUNT(*)::INTEGER FROM shopping_items s
                 WHERE s.created_by = u.user_id AND s.approval_status = 'rejected')
            ) AS rejected_cnt
        FROM users u
        WHERE u.household_id = get_my_household_id()
    )
    SELECT
        s.uid,
        s.uname,
        s.urole,
        s.uowner,
        s.added_30d,
        s.pending_cnt,
        s.approved_cnt,
        s.rejected_cnt,
        CASE
            WHEN (s.approved_cnt + s.rejected_cnt) > 0
            THEN ROUND((s.approved_cnt::NUMERIC / (s.approved_cnt + s.rejected_cnt)) * 100, 2)
            ELSE 0::NUMERIC
        END
    FROM stats s
    ORDER BY s.added_30d DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_member_activity_stats() TO authenticated;
