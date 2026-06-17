# Regression Test Plan - May 2026

**Last Updated:** 2026-05-28  
**Test Phase:** Safe delivery / pre-TestFlight  
**Platform:** iOS (GrubShelf App)

**Record results in [REGRESSION_EXECUTION_LOG.md](REGRESSION_EXECUTION_LOG.md)** before TestFlight or App Store submission.

## Overview

This document provides a comprehensive manual testing checklist to verify that recent changes haven't introduced regressions and that new features work as expected.

## Test Environment Setup

### Prerequisites
- [ ] Latest build installed on physical iOS device
- [ ] Test user account created
- [ ] Test household set up with multiple members (admin + non-admin)
- [ ] Network connectivity (WiFi + Cellular for testing)
- [ ] Notification permissions granted

### Test Data Preparation
- [ ] At least 2 test users in the same household
- [ ] One admin user, one standard member user
- [ ] Sample pantry items in various states (pending, approved, depleted)
- [ ] Sample shopping items in cart
- [ ] At least one pending approval item

## Section 1: Authentication Flows

### 1.1 Apple Sign In
- [ ] **Test:** Tap "Sign in with Apple"
- [ ] **Expected:** Apple ID prompt appears
- [ ] **Test:** Complete sign in flow
- [ ] **Expected:** User successfully authenticated
- [ ] **Test:** Check profile shows Apple ID email
- [ ] **Expected:** Profile data populated correctly

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 1.2 Google Sign In
- [ ] **Test:** Tap "Sign in with Google"
- [ ] **Expected:** Google sign-in sheet appears
- [ ] **Test:** Complete sign in flow
- [ ] **Expected:** User successfully authenticated
- [ ] **Test:** Check profile shows Google email
- [ ] **Expected:** Profile data populated correctly

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 1.3 Email/Password Login
- [ ] **Test:** Enter valid email and password
- [ ] **Expected:** Login successful
- [ ] **Test:** Enter invalid credentials
- [ ] **Expected:** Error message shown with recovery option
- [ ] **Test:** Tap "Forgot Password?"
- [ ] **Expected:** Password reset email sent confirmation shown

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 1.4 Password Reset Flow (OTP — primary path)
- [ ] **Test:** Email user taps "Forgot password" and submits email
- [ ] **Expected:** Navigates to 6-digit code screen (`PasswordResetCodeView`)
- [ ] **Test:** Enter valid code from email
- [ ] **Expected:** Navigates to set-new-password screen (`CompletePasswordResetView`)
- [ ] **Test:** Submit new password
- [ ] **Expected:** Signed in; sign out and sign in with new password works
- [ ] **Test:** Wrong or expired code
- [ ] **Expected:** Clear error; can retry or resend (cooldown respected)
- [ ] **Test:** Cancel mid-flow
- [ ] **Expected:** Can return to welcome; no stuck reset state

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 1.4b OAuth Forgot Password Block
- [ ] **Test:** Apple or Google account taps "Forgot password"
- [ ] **Expected:** Message explains to use same provider; no reset email sent

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 1.5 Profile Permissions (Recent Fix)
- [ ] **Test:** View own profile as admin
- [ ] **Expected:** Can view and edit profile fields
- [ ] **Test:** View own profile as member
- [ ] **Expected:** Can view and edit own profile fields
- [ ] **Test:** Try to access household settings as non-admin
- [ ] **Expected:** Restricted actions are disabled or hidden

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 2: Household Flows

### 2.1 Household Creation
- [ ] **Test:** Create new household from scratch
- [ ] **Expected:** Household created, user is owner/admin
- [ ] **Test:** Verify household name appears in app
- [ ] **Expected:** Household name displayed correctly

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.2 Email-Based Invite Flow (Recent Fix)
- [ ] **Test:** Admin or owner invites new member via email (members cannot invite — migration `074`)
- [ ] **Expected:** Invite sent, email received by invitee
- [ ] **Test:** Member attempts to invite
- [ ] **Expected:** Invite UI hidden or blocked
- [ ] **Test:** New user signs up with same email
- [ ] **Expected:** Invite automatically matched and accepted
- [ ] **Test:** Check household shows new member
- [ ] **Expected:** New member appears in household members list
- [ ] **Test:** Verify member can see household name during invite
- [ ] **Expected:** Household name visible before accepting

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.3 Invite Code Flow
- [ ] **Test:** Generate invite code as admin
- [ ] **Expected:** Code displayed
- [ ] **Test:** Enter code as new user
- [ ] **Expected:** Invite accepted, user joins household
- [ ] **Test:** Try expired invite code
- [ ] **Expected:** Error message with clear recovery option

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.4 Member Permissions & Roles
- [ ] **Test:** View members list as admin
- [ ] **Expected:** All members shown with roles
- [ ] **Test:** Attempt role change as admin
- [ ] **Expected:** Role change succeeds
- [ ] **Test:** Attempt role change as non-admin
- [ ] **Expected:** Action disabled or error shown
- [ ] **Test:** Verify member sees their role clearly
- [ ] **Expected:** Role badge/indicator visible

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.5 Pending Approvals UI (Recent Addition)
- [ ] **Test:** Create pending items as non-admin
- [ ] **Expected:** Items marked as pending
- [ ] **Test:** View approvals tab as admin
- [ ] **Expected:** Pending items listed with counts
- [ ] **Test:** Tap pending approval notification (foreground, background, **app killed**)
- [ ] **Expected:** Opens Pending Approvals sheet (cold start uses `NotificationNavigationStore`)
- [ ] **Test:** Approve one item and reject one item individually (primary path)
- [ ] **Expected:** Action completes, UI updates immediately; member sees outcome
- [ ] **Test:** With 3+ pending items, use "Approve all" per section (secondary)
- [ ] **Expected:** Bulk approve clears queue; toast count correct

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.6 Multiple Pending Invites
- [ ] **Test:** Two pending invites for same email; sign in
- [ ] **Expected:** First invite sheet shown; after accept or decline, second appears
- [ ] **Test:** Swipe-dismiss first invite sheet
- [ ] **Expected:** Treated as decline for that invite only; second invite still shown

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 2.7 Guest Role Display
- [ ] **Test:** User with `guest` role in household
- [ ] **Expected:** Family list shows "Guest" (not "Member"); read-only item actions

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 3: Shopping & Catalog Behavior

### 3.1 Catalog Search (Recent Fix: Water/Blackberry Merge)
- [ ] **Test:** Search for "Water"
- [ ] **Expected:** Results show water items from catalog
- [ ] **Test:** Select catalog item "Spring Water"
- [ ] **Expected:** Item added with catalog_id set
- [ ] **Test:** Search for "Blackberry"
- [ ] **Expected:** Blackberry items appear
- [ ] **Test:** Select "Blackberry Jam"
- [ ] **Expected:** Item added with correct catalog_id
- [ ] **Test:** Verify no incorrect merging of different items
- [ ] **Expected:** Water and Blackberry remain separate items

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 3.2 Shopping Item Creation
- [ ] **Test:** Add custom item (not from catalog)
- [ ] **Expected:** Item added to shopping list, catalog_id is null
- [ ] **Test:** Add item from catalog
- [ ] **Expected:** Item added with catalog_id populated
- [ ] **Test:** Check database or UI for catalog_id
- [ ] **Expected:** Catalog items have ID, custom items don't

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 3.3 Shopping List Management
- [ ] **Test:** Mark item as purchased
- [ ] **Expected:** Item moves to purchased state
- [ ] **Test:** Un-mark item
- [ ] **Expected:** Item returns to unpurchased
- [ ] **Test:** Delete item
- [ ] **Expected:** Item removed from list
- [ ] **Test:** Edit item quantity
- [ ] **Expected:** Quantity updated immediately

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 3.4 Duplicate Prevention
- [ ] **Test:** Try to add same catalog item twice
- [ ] **Expected:** System prevents duplicate OR merges quantity
- [ ] **Test:** Try to add similar custom items
- [ ] **Expected:** System handles appropriately (warn or allow)

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 4: Notification System

### 4.1 Notification Tap Destinations (Recent Addition)
- [ ] **Test:** Tap notification: "Item pending approval"
- [ ] **Expected:** Opens app to Approvals tab
- [ ] **Test:** Tap notification: "Item approved"
- [ ] **Expected:** Opens app to relevant view (pantry/shopping)
- [ ] **Test:** Tap notification: "New shopping item"
- [ ] **Expected:** Opens app to Shopping tab
- [ ] **Test:** Tap notification: "Member joined"
- [ ] **Expected:** Opens app to Home or Members tab

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 4.2 Notification Reliability (Recent Improvements)
- [ ] **Test:** Create item while app in background
- [ ] **Expected:** Notification appears on device
- [ ] **Test:** Background refresh triggered
- [ ] **Expected:** Badge count updates
- [ ] **Test:** Check notification suppression (already handled items)
- [ ] **Expected:** No duplicate notifications for same event

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 4.3 Push Notifications (NEW - Requires APNs Setup)
**Note:** Only test after APNs credentials are configured.

- [ ] **Test:** Create item pending approval as non-admin
- [ ] **Expected:** Admin receives PUSH notification (not just in-app)
- [ ] **Test:** Tap push notification
- [ ] **Expected:** App opens to correct destination
- [ ] **Test:** Check device token registered
- [ ] **Expected:** Token exists in push_device_tokens table
- [ ] **Test:** Verify push notification content
- [ ] **Expected:** Title and body match event

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail | ⬜ Blocked (APNs not configured)

**Notes:**
```
```

## Section 5: Pantry Management

### 5.1 Pantry Item Creation
- [ ] **Test:** Add item as admin
- [ ] **Expected:** Item added directly as approved
- [ ] **Test:** Add item as non-admin member
- [ ] **Expected:** Item added as pending (if approval required)
- [ ] **Test:** Edit item details
- [ ] **Expected:** Changes saved immediately

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 5.2 Pantry Item Status Changes
- [ ] **Test:** Mark item as running low
- [ ] **Expected:** Status updates, visual indicator changes
- [ ] **Test:** Mark item as depleted
- [ ] **Expected:** Status updates, item moves to depleted section
- [ ] **Test:** Restock depleted item
- [ ] **Expected:** Item returns to pantry, quantity reset

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 5.3 Transfer Flow (Recent Gating)
- [ ] **Test:** Try to transfer with incomplete items
- [ ] **Expected:** Transfer CTA hidden or disabled
- [ ] **Test:** Complete all shopping items
- [ ] **Expected:** Transfer CTA appears/enables
- [ ] **Test:** Execute transfer
- [ ] **Expected:** Items moved from shopping to pantry
- [ ] **Test:** Verify receipt logging (single-sheet flow)
- [ ] **Expected:** Receipt logged in one step, no nested modals

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 6: In-Flight Guards & Duplicate Prevention

### 6.1 Duplicate Submit Prevention (Recent Addition)
- [ ] **Test:** Rapidly tap "Add Item" button multiple times
- [ ] **Expected:** Only one item created, button disabled during submit
- [ ] **Test:** Rapidly tap "Approve" multiple times
- [ ] **Expected:** Only one approval processed
- [ ] **Test:** Submit form, then quickly tap submit again
- [ ] **Expected:** Second tap ignored, no duplicate submission

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 6.2 In-Flight State Indicators
- [ ] **Test:** Trigger any action (add/edit/delete)
- [ ] **Expected:** Loading indicator shown immediately
- [ ] **Test:** Check button state during action
- [ ] **Expected:** Button disabled, can't re-click
- [ ] **Test:** Wait for action completion
- [ ] **Expected:** Success/error state shown, UI re-enabled

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 6.3 Action Feedback & Recovery
- [ ] **Test:** Complete successful action
- [ ] **Expected:** Toast/confirmation message shown
- [ ] **Test:** Trigger error (e.g., network off)
- [ ] **Expected:** Error message with recovery option shown
- [ ] **Test:** Follow recovery suggestion
- [ ] **Expected:** User can retry or fix issue

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 7: UX Friction Items from Sprint Plan

### 7.1 Receipt Logging (Single-Sheet Flow)
- [ ] **Test:** Navigate to receipt logging from shopping
- [ ] **Expected:** Single sheet appears (no nested modals)
- [ ] **Test:** Enter receipt details
- [ ] **Expected:** Form is clear and straightforward
- [ ] **Test:** Submit receipt
- [ ] **Expected:** Sheet dismisses, success confirmation shown

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 7.2 Context Preservation Between Tabs
- [ ] **Test:** Apply filters on Pantry tab
- [ ] **Expected:** Filters active
- [ ] **Test:** Switch to Shopping tab, then back to Pantry
- [ ] **Expected:** Filters still applied (context preserved)
- [ ] **Test:** Scroll down on a list, switch tabs, return
- [ ] **Expected:** Scroll position preserved (if expected by design)

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 7.3 Error Recovery Messages
- [ ] **Test:** Turn off network, attempt action
- [ ] **Expected:** "No internet connection" error with retry option
- [ ] **Test:** Invalid data entry
- [ ] **Expected:** Clear validation message with guidance
- [ ] **Test:** Permission denied error
- [ ] **Expected:** Message explains role requirements

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 8: Offline & Error Handling

### 8.1 Offline Behavior
- [ ] **Test:** Turn off WiFi and cellular
- [ ] **Expected:** App shows offline indicator
- [ ] **Test:** Try to add/edit item
- [ ] **Expected:** Error with "retry when online" option
- [ ] **Test:** Turn network back on
- [ ] **Expected:** App reconnects, cached data syncs

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 8.2 Network Recovery
- [ ] **Test:** Start action, turn off network mid-action
- [ ] **Expected:** Error shown with retry option
- [ ] **Test:** Turn network back on and retry
- [ ] **Expected:** Action completes successfully

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 9: Performance & Stability

### 9.1 App Launch & Startup
- [ ] **Test:** Cold start (app not in memory)
- [ ] **Expected:** App launches within 2-3 seconds
- [ ] **Test:** Warm start (app in background)
- [ ] **Expected:** App resumes instantly
- [ ] **Test:** Check for crashes on startup
- [ ] **Expected:** No crashes, stable launch

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

### 9.2 Memory & Resource Usage
- [ ] **Test:** Use app for extended period (30+ minutes)
- [ ] **Expected:** No noticeable slowdowns
- [ ] **Test:** Navigate through all tabs repeatedly
- [ ] **Expected:** Smooth transitions, no lag
- [ ] **Test:** Check device temperature
- [ ] **Expected:** No excessive heating

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Section 10: Deep Linking

### 10.1 Deep Link Handling
- [ ] **Test:** Tap email link (invite/reset password)
- [ ] **Expected:** App opens to correct screen
- [ ] **Test:** Tap push notification
- [ ] **Expected:** App opens to relevant tab/item
- [ ] **Test:** Handle deep link while app is closed
- [ ] **Expected:** App launches and navigates correctly
- [ ] **Test:** Handle deep link while app is in background
- [ ] **Expected:** App foregrounds and navigates correctly

**Status:** ⬜ Not Started | ⬜ In Progress | ⬜ Pass | ⬜ Fail

**Notes:**
```
```

## Test Summary

### Coverage Statistics
- Total test sections: 10
- Total test cases: ~80
- Critical path tests: ~30
- Tests passed: ___
- Tests failed: ___
- Tests blocked: ___
- Tests not started: ___

### Critical Issues Found
```
Issue #1:
Description:
Severity: High | Medium | Low
Steps to Reproduce:
Expected vs Actual:

Issue #2:
...
```

### Non-Critical Issues Found
```
Issue #1:
Description:
Severity: High | Medium | Low
Steps to Reproduce:
Expected vs Actual:
```

### Recommendations
```
Based on testing results:
1. 
2. 
3. 
```

### Sign-Off

**Tester Name:** _________________  
**Date Completed:** _________________  
**Overall Assessment:** ⬜ Pass | ⬜ Pass with Minor Issues | ⬜ Fail | ⬜ Blocked

**Notes:**
```
```

## Appendix: Test Data References

### Test User Accounts
```
Admin User:
- Email: admin@test.grubshelf.app
- Password: [secure]
- User ID: [uuid]

Member User:
- Email: member@test.grubshelf.app
- Password: [secure]
- User ID: [uuid]
```

### Test Household
```
Household Name: Test Household
Household ID: [uuid]
Members: 2 (1 admin, 1 member)
```

### Useful SQL Queries for Verification

```sql
-- Check push device tokens
SELECT user_id, token, platform, updated_at 
FROM push_device_tokens;

-- Check recent notifications
SELECT user_id, type, title, body, read, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;

-- Check shopping items with catalog_id
SELECT name, catalog_id, created_by 
FROM shopping_items 
WHERE household_id = 'your-household-id';

-- Check pending approvals
SELECT item_type, name, approval_status, created_by 
FROM (
  SELECT 'pantry' as item_type, name, approval_status, created_by 
  FROM pantry_items 
  WHERE approval_status = 'pending'
  UNION ALL
  SELECT 'shopping' as item_type, name, approval_status, created_by 
  FROM shopping_items 
  WHERE approval_status = 'pending'
) pending_items;
```
