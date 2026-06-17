-- GrubShelf Migration 043: Notify admins when members submit pending items

CREATE OR REPLACE FUNCTION notify_admins_pending_item()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
    v_creator_name TEXT;
    v_item_type TEXT;
BEGIN
    IF NEW.approval_status IS DISTINCT FROM 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT name INTO v_creator_name
    FROM users WHERE user_id = NEW.created_by;

    v_item_type := CASE TG_TABLE_NAME
        WHEN 'pantry_items' THEN 'pantry'
        WHEN 'shopping_items' THEN 'shopping'
        ELSE 'item'
    END;

    FOR v_admin_id IN
        SELECT user_id FROM users
        WHERE household_id = NEW.household_id
          AND role = 'admin'
    LOOP
        PERFORM create_notification(
            v_admin_id,
            'item_pending_approval',
            'New Item Pending Approval',
            COALESCE(v_creator_name, 'A member') || ' added "' || NEW.name || '" to ' || v_item_type,
            jsonb_build_object(
                'item_id', NEW.item_id,
                'item_name', NEW.name,
                'item_type', v_item_type,
                'created_by', NEW.created_by
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_admins_pantry_pending ON pantry_items;
CREATE TRIGGER notify_admins_pantry_pending
    AFTER INSERT ON pantry_items
    FOR EACH ROW
    WHEN (NEW.approval_status = 'pending')
    EXECUTE FUNCTION notify_admins_pending_item();

DROP TRIGGER IF EXISTS notify_admins_shopping_pending ON shopping_items;
CREATE TRIGGER notify_admins_shopping_pending
    AFTER INSERT ON shopping_items
    FOR EACH ROW
    WHEN (NEW.approval_status = 'pending')
    EXECUTE FUNCTION notify_admins_pending_item();
