-- GrubShelf Migration 044: Approval/rejection notifications and audit logging

CREATE OR REPLACE FUNCTION approve_pantry_item(p_item_id UUID)
RETURNS SETOF pantry_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
    v_item_name TEXT;
    v_creator_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    SELECT household_id, name, created_by
    INTO v_household_id, v_item_name, v_creator_id
    FROM pantry_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    IF v_creator_id IS NOT NULL AND v_creator_id != auth.uid() THEN
        PERFORM create_notification(
            v_creator_id,
            'item_approved',
            'Item Approved',
            'Your pantry item "' || v_item_name || '" has been approved',
            jsonb_build_object('item_id', p_item_id, 'item_name', v_item_name, 'item_type', 'pantry')
        );
    END IF;

    PERFORM log_audit_event(
        'item_approved',
        'pantry_items',
        p_item_id,
        jsonb_build_object('item_name', v_item_name, 'approved_by', auth.uid())
    );

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
    v_item_name TEXT;
    v_creator_id UUID;
    v_body TEXT;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject items';
    END IF;

    SELECT household_id, name, created_by
    INTO v_household_id, v_item_name, v_creator_id
    FROM pantry_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    v_body := 'Your pantry item "' || v_item_name || '" was rejected';
    IF p_reason IS NOT NULL AND char_length(trim(p_reason)) > 0 THEN
        v_body := v_body || ': ' || p_reason;
    END IF;

    IF v_creator_id IS NOT NULL AND v_creator_id != auth.uid() THEN
        PERFORM create_notification(
            v_creator_id,
            'item_rejected',
            'Item Rejected',
            v_body,
            jsonb_build_object(
                'item_id', p_item_id,
                'item_name', v_item_name,
                'item_type', 'pantry',
                'reason', p_reason
            )
        );
    END IF;

    PERFORM log_audit_event(
        'item_rejected',
        'pantry_items',
        p_item_id,
        jsonb_build_object('item_name', v_item_name, 'rejected_by', auth.uid(), 'reason', p_reason)
    );

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

CREATE OR REPLACE FUNCTION approve_shopping_item(p_item_id UUID)
RETURNS SETOF shopping_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_household_id UUID;
    v_item_name TEXT;
    v_creator_id UUID;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can approve items';
    END IF;

    SELECT household_id, name, created_by
    INTO v_household_id, v_item_name, v_creator_id
    FROM shopping_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    IF v_creator_id IS NOT NULL AND v_creator_id != auth.uid() THEN
        PERFORM create_notification(
            v_creator_id,
            'item_approved',
            'Item Approved',
            'Your shopping item "' || v_item_name || '" has been approved',
            jsonb_build_object('item_id', p_item_id, 'item_name', v_item_name, 'item_type', 'shopping')
        );
    END IF;

    PERFORM log_audit_event(
        'item_approved',
        'shopping_items',
        p_item_id,
        jsonb_build_object('item_name', v_item_name, 'approved_by', auth.uid())
    );

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
    v_item_name TEXT;
    v_creator_id UUID;
    v_body TEXT;
BEGIN
    IF NOT is_household_admin() THEN
        RAISE EXCEPTION 'Only admins can reject items';
    END IF;

    SELECT household_id, name, created_by
    INTO v_household_id, v_item_name, v_creator_id
    FROM shopping_items
    WHERE item_id = p_item_id;

    IF v_household_id IS NULL OR v_household_id != get_my_household_id() THEN
        RAISE EXCEPTION 'Item not found or access denied';
    END IF;

    v_body := 'Your shopping item "' || v_item_name || '" was rejected';
    IF p_reason IS NOT NULL AND char_length(trim(p_reason)) > 0 THEN
        v_body := v_body || ': ' || p_reason;
    END IF;

    IF v_creator_id IS NOT NULL AND v_creator_id != auth.uid() THEN
        PERFORM create_notification(
            v_creator_id,
            'item_rejected',
            'Item Rejected',
            v_body,
            jsonb_build_object(
                'item_id', p_item_id,
                'item_name', v_item_name,
                'item_type', 'shopping',
                'reason', p_reason
            )
        );
    END IF;

    PERFORM log_audit_event(
        'item_rejected',
        'shopping_items',
        p_item_id,
        jsonb_build_object('item_name', v_item_name, 'rejected_by', auth.uid(), 'reason', p_reason)
    );

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
