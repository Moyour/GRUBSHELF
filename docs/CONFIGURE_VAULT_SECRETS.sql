-- Configure Vault Secrets for Push Notification Trigger
-- Run this in Supabase Dashboard → SQL Editor for project: dpsyrzffwpfrsrsmsidm
-- Last updated: 2026-05-25

-- INSTRUCTIONS:
-- 1. Go to: https://supabase.com/dashboard/project/dpsyrzffwpfrsrsmsidm/sql/new
-- 2. Replace the placeholder values below with actual values
-- 3. Run this SQL

-- Get your actual values from:
-- - Project URL: https://supabase.com/dashboard/project/dpsyrzffwpfrsrsmsidm/settings/api
--   (Look for "Project URL" - should be: https://dpsyrzffwpfrsrsmsidm.supabase.co)
-- - Service Role Key: Same page, under "Project API keys", reveal the "service_role" key

-- Insert or update project_url secret
INSERT INTO vault.secrets (secret, name, description)
VALUES (
    'https://dpsyrzffwpfrsrsmsidm.supabase.co',  -- Replace with your actual project URL
    'project_url',
    'Supabase project URL for push notification edge function calls'
)
ON CONFLICT (name) DO UPDATE 
SET 
    secret = EXCLUDED.secret,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Insert or update service_role_key secret
INSERT INTO vault.secrets (secret, name, description)
VALUES (
    'YOUR_SERVICE_ROLE_KEY_HERE',  -- Replace with your actual service role key (starts with eyJ...)
    'service_role_key',
    'Service role key for authenticated edge function calls from database triggers'
)
ON CONFLICT (name) DO UPDATE 
SET 
    secret = EXCLUDED.secret,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Verify secrets were created
SELECT name, description, created_at, updated_at
FROM vault.secrets
WHERE name IN ('project_url', 'service_role_key');

-- Expected output:
-- | name              | description                                              | created_at          | updated_at          |
-- |-------------------|----------------------------------------------------------|---------------------|---------------------|
-- | project_url       | Supabase project URL for push notification edge...      | 2026-05-25 ...      | 2026-05-25 ...      |
-- | service_role_key  | Service role key for authenticated edge function...     | 2026-05-25 ...      | 2026-05-25 ...      |
