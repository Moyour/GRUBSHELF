-- GrubShelf Migration 059: Materialized view for pending approval counts

CREATE MATERIALIZED VIEW IF NOT EXISTS pending_approval_counts AS
SELECT
    household_id,
    COUNT(*) FILTER (WHERE source = 'pantry')::INTEGER AS pending_pantry_count,
    COUNT(*) FILTER (WHERE source = 'shopping')::INTEGER AS pending_shopping_count,
    MAX(latest_pending_at) AS latest_pending_at
FROM (
    SELECT household_id, 'pantry'::TEXT AS source, created_at AS latest_pending_at
    FROM pantry_items
    WHERE approval_status = 'pending'

    UNION ALL

    SELECT household_id, 'shopping'::TEXT AS source, created_at AS latest_pending_at
    FROM shopping_items
    WHERE approval_status = 'pending'
) combined
GROUP BY household_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_approval_counts_household
    ON pending_approval_counts (household_id);

CREATE OR REPLACE FUNCTION refresh_pending_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY pending_approval_counts;
EXCEPTION
    WHEN OTHERS THEN
        REFRESH MATERIALIZED VIEW pending_approval_counts;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_refresh_pending_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM refresh_pending_counts();
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS refresh_pending_counts_pantry ON pantry_items;
CREATE TRIGGER refresh_pending_counts_pantry
    AFTER INSERT OR UPDATE OR DELETE ON pantry_items
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_refresh_pending_counts();

DROP TRIGGER IF EXISTS refresh_pending_counts_shopping ON shopping_items;
CREATE TRIGGER refresh_pending_counts_shopping
    AFTER INSERT OR UPDATE OR DELETE ON shopping_items
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_refresh_pending_counts();

-- Initial populate
SELECT refresh_pending_counts();

GRANT EXECUTE ON FUNCTION refresh_pending_counts() TO authenticated;
