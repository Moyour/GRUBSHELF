-- GrubShelf Migration 069: Push device tokens + dispatch hooks

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user
    ON push_device_tokens (user_id, updated_at DESC);

ALTER TABLE push_device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own push tokens"
    ON push_device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION upsert_push_device_token(
    p_token TEXT,
    p_platform TEXT DEFAULT 'ios'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO push_device_tokens (user_id, token, platform, updated_at)
    VALUES (auth.uid(), p_token, COALESCE(NULLIF(p_platform, ''), 'ios'), NOW())
    ON CONFLICT (user_id, token)
    DO UPDATE SET updated_at = NOW(), platform = EXCLUDED.platform;
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_push_device_token(TEXT, TEXT) TO authenticated;

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
    IF NEW.type NOT IN ('item_pending_approval') THEN
        RETURN NEW;
    END IF;

    SELECT decrypted_secret INTO v_project_url
    FROM vault.decrypted_secrets
    WHERE name = 'project_url'
    LIMIT 1;

    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
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

DROP TRIGGER IF EXISTS dispatch_push_on_notification_insert ON notifications;
CREATE TRIGGER dispatch_push_on_notification_insert
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION dispatch_push_for_notification();
