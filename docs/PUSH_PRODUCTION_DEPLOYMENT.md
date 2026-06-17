# Push Notification Production Deployment Checklist

**Date Created:** 2026-05-25  
**Status:** In Progress

## Overview

This document tracks the production rollout of push notifications infrastructure including:
- APNs device token registration
- Supabase edge function for push dispatch
- Database trigger for automatic notification dispatch
- Production secrets configuration

## Prerequisites Checklist

- [x] Push notification code implemented in iOS app (PushNotificationService.swift)
- [x] Edge function created (supabase/functions/send-push/index.ts)
- [x] Migration created (069_push_device_tokens.sql)
- [x] Local testing completed
- [ ] Production Supabase project accessible
- [ ] Apple Developer account access for APNs credentials
- [ ] Supabase admin access for secrets configuration

## Deployment Steps

### 1. Apply Database Migration

**Status:** ✅ COMPLETED (2026-05-25)  
**Command:**
```bash
cd /Users/moyoursalau/Desktop/WebDesign/FoodPan
supabase db push
```

**What this does:**
- Creates `push_device_tokens` table
- Adds RLS policies for token management
- Creates `upsert_push_device_token` RPC function
- Creates `dispatch_push_for_notification` trigger function
- Enables pg_net extension for HTTP requests

**Verification:**
```bash
supabase db remote list-changes
```

### 2. Deploy Edge Function

**Status:** ✅ COMPLETED (2026-05-25)  
**Deployed Version:** v1  
**Function ID:** 417c1613-8357-49e8-b62f-10ee41f50a75  
**Command:**
```bash
supabase functions deploy send-push
```

**What this does:**
- Deploys the send-push edge function to production
- Enables HTTP endpoint: `{project_url}/functions/v1/send-push`

**Verification:**
```bash
supabase functions list
```

### 3. Configure APNs Credentials

**Status:** ⏳ PENDING - Requires Apple Developer Account Access  
**See:** docs/APNS_SETUP_GUIDE.md for detailed instructions  
**Required Secrets:**

You need to obtain these from Apple Developer Console:
- `APNS_KEY_ID` - Apple Push Notification service Key ID
- `APNS_TEAM_ID` - Apple Developer Team ID
- `APNS_PRIVATE_KEY` - APNs private key (P8 file content)
- `APNS_BUNDLE_ID` - App bundle ID (e.g., com.grubshelf.GrubShelf)
- `APNS_USE_SANDBOX` - "true" for sandbox, "false" for production

**How to get APNs credentials:**
1. Go to https://developer.apple.com/account/resources/authkeys/list
2. Create or use existing APNs key
3. Download the .p8 file
4. Note the Key ID and Team ID

**Commands to set secrets:**
```bash
# Set APNs Key ID
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"

# Set APNs Team ID
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"

# Set APNs Bundle ID
supabase secrets set APNS_BUNDLE_ID="com.grubshelf.GrubShelf"

# Set APNs sandbox mode (false for production)
supabase secrets set APNS_USE_SANDBOX="false"

# Set APNs Private Key (replace newlines with \n)
supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGT...your key here...\n-----END PRIVATE KEY-----"
```

**Verification:**
```bash
supabase secrets list
```

### 4. Configure Vault Secrets for Trigger

**Status:** ⏳ PENDING - SQL script ready  
**See:** docs/CONFIGURE_VAULT_SECRETS.sql  
**Required for:** The database trigger needs these to call the edge function

**Get project URL and service role key:**
```bash
# This will show your project details
supabase status
```

**Set vault secrets via SQL:**
```sql
-- Insert project_url secret
INSERT INTO vault.secrets (secret, name)
VALUES ('https://your-project-ref.supabase.co', 'project_url')
ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;

-- Insert service_role_key secret
INSERT INTO vault.secrets (secret, name)
VALUES ('your-service-role-key-here', 'service_role_key')
ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;
```

**Alternative using Supabase Dashboard:**
1. Go to Database → SQL Editor
2. Run the above SQL queries with actual values

### 5. Test Push Notifications End-to-End

**Status:** ⏳ BLOCKED - Waiting for APNs configuration  
**Test Steps:**

1. **Verify device token registration:**
   - Open the iOS app
   - Grant notification permissions
   - Check that token is saved in `push_device_tokens` table

2. **Test manual push:**
   ```bash
   curl -X POST "https://your-project.supabase.co/functions/v1/send-push" \
     -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "user_id": "your-test-user-id",
       "title": "Test Push",
       "body": "Testing push notification system",
       "category": "GENERAL"
     }'
   ```

3. **Test automatic push via trigger:**
   - Create a notification that triggers push (e.g., item_pending_approval)
   - Verify push is received on device
   - Verify tap destination works correctly

## Regression Testing Checklist

### Shopping Merge Behavior
- [ ] Test catalog item search and selection
- [ ] Verify "Water/Blackberry" style merge cases work correctly
- [ ] Test duplicate prevention
- [ ] Verify catalog_id is set correctly

### Notification Behavior
- [ ] Test notification tap destinations for each category
- [ ] Verify deep linking works (approvals, shop, etc.)
- [ ] Test background refresh scheduling
- [ ] Verify duplicate notification suppression

### Auth Flows
- [ ] Test Apple Sign In
- [ ] Test Google Sign In
- [ ] Test email/password login
- [ ] Test password reset flow
- [ ] Verify profile permission fixes

### Household Flows
- [ ] Test household creation
- [ ] Test invite flow (email-based matching)
- [ ] Test accept invite
- [ ] Test member permissions
- [ ] Verify pending approvals UI

### Pantry & Transfer Flows
- [ ] Test pantry item creation
- [ ] Test item status changes
- [ ] Test transfer flow (only shows when items complete)
- [ ] Test receipt logging (single-sheet flow)
- [ ] Verify in-flight guards prevent duplicate submissions

## Rollback Plan

If issues arise after deployment:

1. **Disable trigger temporarily:**
   ```sql
   DROP TRIGGER IF EXISTS dispatch_push_on_notification_insert ON notifications;
   ```

2. **Revert migration if needed:**
   ```bash
   supabase db remote commit  # Get current state
   # Then manually revert the push tables
   ```

3. **Undeploy function:**
   ```bash
   supabase functions delete send-push
   ```

## Notes

- Push notifications are best-effort; failures won't break app functionality
- The edge function gracefully handles missing APNs configuration
- iOS app already has fallback to local notifications
- Monitor logs after deployment: `supabase functions logs send-push`

## Current Status Summary

**What's Ready:**
- ✅ iOS app code (PushNotificationService)
- ✅ Edge function code
- ✅ Database migration file
- ✅ Trigger logic
- ✅ Migration applied to production (069_push_device_tokens)
- ✅ Edge function deployed to production (send-push)
- ✅ Notification system tables created (042-044)

**What's Needed:**
- ⏳ Configure APNs credentials (requires Apple Developer access) - **BLOCKED: Need Apple Developer account**
- ⏳ Configure vault secrets (SQL script ready in docs/CONFIGURE_VAULT_SECRETS.sql)
- ⏳ End-to-end testing (after APNs configured)
- ⏳ Regression testing (comprehensive plan in docs/REGRESSION_TEST_PLAN.md)

## Next Actions

1. **Immediate:** Apply migration and deploy edge function (can be done now)
2. **Requires credentials:** Configure APNs secrets (need Apple Developer access)
3. **After credentials:** Test push notifications
4. **Final:** Complete regression testing checklist
