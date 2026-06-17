-- GrubShelf Migration 070: Push notification configuration (alternative to vault)

-- Create a secure configuration table for push notification settings
CREATE TABLE IF NOT EXISTS push_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Disable RLS but don't allow public access (only SECURITY DEFINER functions can access)
ALTER TABLE push_config ENABLE ROW LEVEL SECURITY;

-- No policies = only SECURITY DEFINER functions can read/write
-- This makes it secure like vault but without the encryption complexity

-- Insert configuration values
INSERT INTO push_config (key, value)
VALUES 
    ('project_url', 'https://dpsyrzffwpfrsrsmsidm.supabase.co'),
    ('service_role_key', 'REPLACE_WITH_YOUR_SERVICE_ROLE_KEY')
ON CONFLICT (key) DO UPDATE 
SET 
    value = EXCLUDED.value,
    updated_at = NOW();

-- Update the trigger function to use push_config instead of vault
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

    -- Read from push_config instead of vault
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
