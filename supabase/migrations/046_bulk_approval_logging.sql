-- GrubShelf Migration 046: Bulk approval notifications and audit logging

CREATE OR REPLACE FUNCTION bulk_approve_pantry_items(p_item_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_item RECORD;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    FOR v_item IN
        SELECT item_id, name, created_by
        FROM pantry_items
        WHERE item_id = ANY(p_item_ids)
          AND household_id = get_my_household_id()
          AND approval_status = 'pending'
    LOOP
        IF v_item.created_by IS NOT NULL AND v_item.created_by != auth.uid() THEN
            PERFORM create_notification(
                v_item.created_by,
                'item_approved',
                'Item Approved',
                'Your pantry item "' || v_item.name || '" has been approved',
                jsonb_build_object('item_id', v_item.item_id, 'item_type', 'pantry')
            );
        END IF;
    END LOOP;

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

    IF v_count > 0 THEN
        PERFORM log_audit_event(
            'bulk_items_approved',
            'pantry_items',
            NULL,
            jsonb_build_object('count', v_count, 'item_ids', p_item_ids)
        );
    END IF;

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION bulk_approve_shopping_items(p_item_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_item RECORD;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    FOR v_item IN
        SELECT item_id, name, created_by
        FROM shopping_items
        WHERE item_id = ANY(p_item_ids)
          AND household_id = get_my_household_id()
          AND approval_status = 'pending'
    LOOP
        IF v_item.created_by IS NOT NULL AND v_item.created_by != auth.uid() THEN
            PERFORM create_notification(
                v_item.created_by,
                'item_approved',
                'Item Approved',
                'Your shopping item "' || v_item.name || '" has been approved',
                jsonb_build_object('item_id', v_item.item_id, 'item_type', 'shopping')
            );
        END IF;
    END LOOP;

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

    IF v_count > 0 THEN
        PERFORM log_audit_event(
            'bulk_items_approved',
            'shopping_items',
            NULL,
            jsonb_build_object('count', v_count, 'item_ids', p_item_ids)
        );
    END IF;

    RETURN v_count;
END;
$$;
