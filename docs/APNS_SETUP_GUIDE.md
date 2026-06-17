# APNs Setup Guide for Push Notifications

**Last Updated:** 2026-05-25  
**Status:** Ready for configuration

## Overview

This guide walks you through obtaining Apple Push Notification Service (APNs) credentials and configuring them in Supabase for production push notifications.

## Prerequisites

- ✅ Migration 069 applied to production database
- ✅ send-push edge function deployed
- ⏳ Apple Developer Account access
- ⏳ Admin access to Apple Developer Console

## Step 1: Generate APNs Key in Apple Developer Console

### 1.1 Navigate to Keys Section

1. Go to https://developer.apple.com/account/resources/authkeys/list
2. Sign in with your Apple Developer account
3. Click the **"+"** button to create a new key

### 1.2 Configure the Key

1. **Key Name:** Enter a descriptive name (e.g., "GrubShelf Production Push")
2. **Key Services:** Check **"Apple Push Notifications service (APNs)"**
3. Click **Continue**
4. Review and click **Register**

### 1.3 Download the Key

1. **Important:** Download the `.p8` file immediately - you can only download it once!
2. Save it securely (e.g., `AuthKey_XXXXXXXXXX.p8`)
3. Note the **Key ID** displayed (10-character string like `ABC123DEFG`)
4. Note your **Team ID** (found in the top-right corner of the Apple Developer page, or in Account → Membership)

### 1.4 Get Your Bundle ID

Your app's Bundle ID should be: `com.grubshelf.GrubShelf`

Verify this in:
- Xcode: Project → Signing & Capabilities → Bundle Identifier
- Apple Developer: Identifiers → App IDs

## Step 2: Prepare APNs Private Key

The `.p8` file you downloaded contains your private key. You need to convert it to a format suitable for Supabase secrets.

### 2.1 Read the .p8 File

Open the file in a text editor. It will look like this:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
...more base64 content...
...ends with...
-----END PRIVATE KEY-----
```

### 2.2 Format for Supabase

For the Supabase secret, you need to replace actual newlines with `\n`:

**Original (multi-line):**
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg
ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdef
-----END PRIVATE KEY-----
```

**Formatted (single line with \n):**
```
-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg\nABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdef\n-----END PRIVATE KEY-----
```

## Step 3: Set Supabase Secrets

### 3.1 Set APNs Secrets via CLI

Open your terminal and run the following commands from your project directory:

```bash
cd /Users/moyoursalau/Desktop/WebDesign/FoodPan

# Set Key ID (10-character string from Apple Developer Console)
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID_HERE"

# Set Team ID (10-character string from Apple Developer Console)
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID_HERE"

# Set Bundle ID
supabase secrets set APNS_BUNDLE_ID="com.grubshelf.GrubShelf"

# Set to false for production, true for sandbox/testing
supabase secrets set APNS_USE_SANDBOX="false"

# Set Private Key (formatted with \n)
supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_CONTENT_HERE\n-----END PRIVATE KEY-----"
```

### 3.2 Verify Secrets

```bash
supabase secrets list
```

You should see:
- APNS_KEY_ID
- APNS_TEAM_ID
- APNS_BUNDLE_ID
- APNS_USE_SANDBOX
- APNS_PRIVATE_KEY

**Note:** The secret values won't be displayed for security reasons, but the keys should be listed.

## Step 4: Configure Vault Secrets for Database Trigger

The database trigger function `dispatch_push_for_notification()` needs to call the edge function. It requires these vault secrets:

### 4.1 Get Your Supabase Project Details

```bash
# Get your project URL
supabase status --linked
```

Look for the API URL, which should be something like:
`https://dpsyrzffwpfrsrsmsidm.supabase.co`

### 4.2 Get Service Role Key

1. Go to https://supabase.com/dashboard/project/dpsyrzffwpfrsrsmsidm/settings/api
2. Find the **"service_role"** key (it's a long JWT token starting with `eyJ...`)
3. Click to reveal and copy it

### 4.3 Set Vault Secrets via SQL

Go to Supabase Dashboard → SQL Editor and run:

```sql
-- Insert project_url secret
INSERT INTO vault.secrets (secret, name)
VALUES ('https://dpsyrzffwpfrsrsmsidm.supabase.co', 'project_url')
ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;

-- Insert service_role_key secret
INSERT INTO vault.secrets (secret, name)
VALUES ('YOUR_SERVICE_ROLE_KEY_HERE', 'service_role_key')
ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;
```

Replace:
- `https://dpsyrzffwpfrsrsmsidm.supabase.co` with your actual project URL
- `YOUR_SERVICE_ROLE_KEY_HERE` with your actual service role key

### 4.4 Verify Vault Secrets

```sql
SELECT name, created_at 
FROM vault.secrets 
WHERE name IN ('project_url', 'service_role_key');
```

You should see both secrets listed (values won't be shown for security).

## Step 5: Test Push Notifications

### 5.1 Test Direct Edge Function Call

```bash
# Get your project URL and service role key first
PROJECT_URL="https://dpsyrzffwpfrsrsmsidm.supabase.co"
SERVICE_ROLE_KEY="your_service_role_key_here"

# Test the edge function directly
curl -X POST "$PROJECT_URL/functions/v1/send-push" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "your-test-user-id-here",
    "title": "Test Push Notification",
    "body": "If you see this, APNs is working!",
    "category": "GENERAL"
  }'
```

Expected response:
```json
{
  "sent": 1,
  "failed": 0
}
```

Or if no device tokens:
```json
{
  "sent": 0,
  "skipped": true,
  "reason": "No device tokens"
}
```

### 5.2 Test End-to-End via App

1. **Register device token:**
   - Open the GrubShelf iOS app
   - Grant notification permissions when prompted
   - The app should automatically register the device token

2. **Verify token saved:**
   ```sql
   SELECT token, platform, updated_at 
   FROM push_device_tokens 
   WHERE user_id = 'your-user-id';
   ```

3. **Trigger a notification:**
   - Create an item pending approval (if you're a non-admin member)
   - Or test with any other notification trigger
   - Check if you receive the push notification on your device

4. **Verify tap destination:**
   - Tap the notification
   - Verify it navigates to the correct screen (e.g., approvals tab)

## Step 6: Monitor and Debug

### 6.1 Check Edge Function Logs

```bash
supabase functions logs send-push --linked
```

Look for:
- Success messages: `APNs delivery succeeded`
- Error messages: `APNs delivery failed`
- Configuration issues: `APNs not configured`

### 6.2 Common Issues

**Issue:** "APNs not configured" response
- **Fix:** Check that all 5 APNs secrets are set correctly
- Verify with `supabase secrets list`

**Issue:** "Invalid token" from APNs
- **Fix:** Verify the device token is correctly formatted (64-character hex string)
- Check that the token was registered with the correct platform (`ios`)

**Issue:** "Bad certificate" or "Forbidden" from APNs
- **Fix:** Verify APNS_PRIVATE_KEY is correctly formatted with `\n` escapes
- Ensure the Key ID and Team ID match your Apple Developer account

**Issue:** "Device token not for topic"
- **Fix:** Verify APNS_BUNDLE_ID matches your app's Bundle Identifier exactly

**Issue:** Push not sent even though trigger fired
- **Fix:** Check vault secrets are set correctly
- Verify the trigger is calling the edge function by checking function logs

### 6.3 Testing Sandbox vs Production

For development/TestFlight builds:
```bash
supabase secrets set APNS_USE_SANDBOX="true"
```

For App Store production builds:
```bash
supabase secrets set APNS_USE_SANDBOX="false"
```

## Security Notes

1. **Never commit APNs keys to git**
2. **Never share your .p8 file publicly**
3. **Store the .p8 file securely** (encrypted backup recommended)
4. **Rotate keys periodically** (Apple allows creating new keys)
5. **Use different keys for dev/staging/production** (optional but recommended)

## Rollback

If you need to disable push notifications temporarily:

```sql
-- Disable the trigger
DROP TRIGGER IF EXISTS dispatch_push_on_notification_insert ON notifications;

-- Re-enable later by running migration 069 again
```

## Next Steps

After completing this setup:
1. ✅ APNs credentials configured
2. ✅ Vault secrets configured
3. ✅ Test push notifications work
4. → Move on to full regression testing
5. → Monitor production logs for the first few days

## Reference Links

- [Apple Developer Console - Keys](https://developer.apple.com/account/resources/authkeys/list)
- [Apple Push Notification Service Documentation](https://developer.apple.com/documentation/usernotifications)
- [Supabase Secrets Management](https://supabase.com/docs/guides/functions/secrets)
- [Supabase Vault](https://supabase.com/docs/guides/database/vault)

## Summary Checklist

- [ ] Generated APNs Key in Apple Developer Console
- [ ] Downloaded .p8 file and noted Key ID and Team ID
- [ ] Set APNS_KEY_ID secret in Supabase
- [ ] Set APNS_TEAM_ID secret in Supabase
- [ ] Set APNS_BUNDLE_ID secret in Supabase
- [ ] Set APNS_USE_SANDBOX secret in Supabase
- [ ] Set APNS_PRIVATE_KEY secret in Supabase (formatted with \n)
- [ ] Set project_url in vault.secrets
- [ ] Set service_role_key in vault.secrets
- [ ] Tested direct edge function call
- [ ] Tested end-to-end push via app
- [ ] Verified tap destinations work correctly
- [ ] Checked logs for errors
