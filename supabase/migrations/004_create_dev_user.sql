-- ============================================================
-- DEV ONLY: Create a pre-confirmed dev user for testing
-- Run this in Supabase SQL Editor to bypass email confirmation
-- ============================================================

DO $$
DECLARE
  dev_uid UUID;
BEGIN
  -- Check if dev user already exists
  SELECT id INTO dev_uid FROM auth.users WHERE email = 'dev@foodpan.test';

  IF dev_uid IS NULL THEN
    -- Create new confirmed user
    dev_uid := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      aud, role
    ) VALUES (
      dev_uid,
      '00000000-0000-0000-0000-000000000000',
      'dev@foodpan.test',
      crypt('devpassword123!', gen_salt('bf')),
      NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}',
      '{"name":"Dev User"}',
      'authenticated',
      'authenticated'
    );

    -- Create identity record (required for sign-in to work)
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      dev_uid, dev_uid,
      jsonb_build_object(
        'sub', dev_uid::text,
        'email', 'dev@foodpan.test',
        'email_verified', true
      ),
      'email', dev_uid::text,
      NOW(), NOW(), NOW()
    );

    RAISE NOTICE 'Created new dev user: %', dev_uid;
  ELSE
    -- User exists but may not be confirmed — confirm them
    UPDATE auth.users
    SET email_confirmed_at = NOW()
    WHERE id = dev_uid AND email_confirmed_at IS NULL;

    RAISE NOTICE 'Dev user already exists (confirmed): %', dev_uid;
  END IF;
END $$;
