-- ============================================================
-- DEV ONLY: Create a pre-confirmed dev user for local testing.
-- Skipped on hosted Supabase (production). Only runs when
-- the instance URL contains 'localhost' or '127.0.0.1'.
-- ============================================================

DO $$
DECLARE
  dev_uid UUID;
  is_local BOOLEAN;
BEGIN
  -- Guard: only run on local Supabase instances
  SELECT (current_setting('app.settings.supabase_url', true) IS NULL
          OR current_setting('app.settings.supabase_url', true) ~* '(localhost|127\.0\.0\.1)')
    INTO is_local;

  IF NOT COALESCE(is_local, true) THEN
    RAISE NOTICE 'Skipping dev user creation on non-local instance.';
    RETURN;
  END IF;

  SELECT id INTO dev_uid FROM auth.users WHERE email = 'dev@grubshelf.test';

  IF dev_uid IS NULL THEN
    dev_uid := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      aud, role
    ) VALUES (
      dev_uid,
      '00000000-0000-0000-0000-000000000000',
      'dev@grubshelf.test',
      crypt('devpassword123!', gen_salt('bf')),
      NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"Dev User"}',
      'authenticated',
      'authenticated'
    );

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      dev_uid, dev_uid,
      jsonb_build_object(
        'sub', dev_uid::text,
        'email', 'dev@grubshelf.test',
        'email_verified', true
      ),
      'email', dev_uid::text,
      NOW(), NOW(), NOW()
    );

    RAISE NOTICE 'Created new dev user: %', dev_uid;
  ELSE
    UPDATE auth.users
    SET email_confirmed_at = NOW()
    WHERE id = dev_uid AND email_confirmed_at IS NULL;

    RAISE NOTICE 'Dev user already exists (confirmed): %', dev_uid;
  END IF;
END $$;
