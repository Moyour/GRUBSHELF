-- GrubShelf Migration 082: Expand push dispatch to item_approved and item_rejected
--
-- Previously only item_pending_approval triggered a push notification.
-- This adds item_approved and item_rejected so users get notified when their
-- submissions are accepted or denied.

CREATE OR REPLACE FUNCTION dispatch_push_for_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_project_url TEXT;
    v_service_role_key TEXT;
BEGIN
    IF NEW.type NOT IN ('item_pending_approval', 'item_approved', 'item_rejected') THEN
        RETURN NEW;
    END IF;

    -- Read from push_config (preferred) or fall back gracefully
    SELECT value INTO v_project_url
    FROM push_config
    WHERE key = 'project_url'
    LIMIT 1;

    SELECT value INTO v_service_role_key
    FROM push_config
    WHERE key = 'service_role_key'
    LIMIT 1;

    IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := v_project_url || '/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_role_key
        ),
        body := jsonb_build_object(
            'user_id', NEW.user_id,
            'title', NEW.title,
            'body', NEW.body,
            'data', NEW.data,
            'category', NEW.type
        )
    );

    RETURN NEW;
END;
$$;
