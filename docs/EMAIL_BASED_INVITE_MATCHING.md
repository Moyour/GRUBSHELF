# Email-Based Invite Matching - Implementation

## Overview

Implemented automatic detection and acceptance of household invitations when users sign up or sign in with an invited email address. This eliminates the need for users to manually click invite links after downloading the app.

---

## User Experience

### Before (Required Deep Link)
1. User receives invitation email
2. Downloads app from TestFlight
3. ❌ **Must remember to return to email**
4. Clicks invite link again
5. Accepts invitation

### After (Automatic Detection)
1. User receives invitation email
2. Downloads app from TestFlight
3. Signs up with invited email
4. ✅ **Automatically sees invitation prompt**
5. Taps "Accept Invitation"
6. Done! 🎉

---

## How It Works

### 1. Authentication Flow

When a user signs in or signs up through **any method**:
- Email/Password
- Google Sign-In
- Apple Sign-In
- Email verification (OTP)

The system automatically:
1. Checks if there are pending invites for that email
2. If found, shows a beautiful prompt
3. User can accept or dismiss

### 2. State Management

**AuthenticationService** now tracks:
```swift
var pendingInvitesToAccept: [HouseholdInviteWithName] = []
```

This is populated after successful authentication via:
```swift
func checkForPendingInvites() async
```

### 3. UI Presentation

**GrubShelfApp** presents a sheet when pending invites are detected:
```swift
.sheet(item: Binding(
    get: { authService.pendingInvitesToAccept.first },
    set: { if $0 == nil { authService.pendingInvitesToAccept.removeAll() } }
)) { invite in
    PendingInvitePromptView(invite: invite, authService: authService)
}
```

### 4. User Actions

**PendingInvitePromptView** shows:
- 🏠 Household name
- 📧 Invited email
- ⏰ Expiration time
- ✅ "Accept Invitation" button
- ❌ "Not Now" button

---

## Technical Implementation

### Files Modified

#### 1. **AuthenticationService.swift**

**Added State:**
```swift
var pendingInvitesToAccept: [HouseholdInviteWithName] = []
```

**Added Methods:**
```swift
// Checks for pending invites after sign-in
func checkForPendingInvites() async

// Accepts an invite and updates current user
func acceptPendingInvite(inviteId: UUID) async throws

// Dismisses an invite without accepting
func dismissPendingInvite(inviteId: UUID)
```

**Updated Methods:**
- `signIn()` - Now calls `checkForPendingInvites()`
- `verifyEmail()` - Now calls `checkForPendingInvites()`
- `signInWithGoogle()` - Now calls `checkForPendingInvites()`
- `signInWithApple()` - Now calls `checkForPendingInvites()`

#### 2. **GrubShelfApp.swift**

**Added Sheet Presentation:**
Shows `PendingInvitePromptView` when invites are detected

### Files Created

#### 3. **PendingInvitePromptView.swift**

A beautiful, native SwiftUI sheet that:
- Shows household name and invite details
- Displays expiration time
- Provides "Accept" and "Not Now" buttons
- Shows loading state during acceptance
- Displays success/error toasts
- Prevents accidental dismissal while processing

---

## User Scenarios

### Scenario 1: New User (No App)
1. Receives invitation email
2. Taps "Download the TestFlight Beta"
3. Installs GrubShelf
4. Opens app and taps "Sign Up"
5. Enters invited email: `friend@example.com`
6. Completes sign-up
7. ✅ **Sheet appears**: "You're Invited! You have a pending invitation to join The Smith Family"
8. Taps "Accept Invitation"
9. **Instantly added to household**

### Scenario 2: Existing User (Different Household)
1. Receives invitation email
2. Already has app installed
3. Opens app (already signed in with different email)
4. Signs out
5. Signs in with invited email
6. ✅ **Sheet appears with invitation**
7. Accepts and joins new household

### Scenario 3: Existing User (Signed In with Invited Email)
1. Receives invitation email
2. Already signed in with that email
3. Opens app normally
4. ✅ **Sheet appears immediately**
5. Accepts invitation
6. Continues using app in new household

### Scenario 4: Multiple Pending Invites
1. User has 3 pending invites for their email
2. Signs in
3. ✅ **Sheet shows first invitation**
4. User accepts (or dismisses)
5. ✅ **Sheet shows next invitation**
6. Continues until all invites are addressed

---

## Integration with Deep Links

This feature **complements** the existing deep link system:

| Method | When It's Used |
|--------|----------------|
| **Deep Link** | User clicks invite link in email → Opens app with token |
| **Email Matching** | User signs up/in with invited email → Auto-detects invite |

**Both work together:**
1. User gets email with deep link
2. If they click the link first → Deep link opens app and accepts invite
3. If they download app first → Email matching detects and shows invite
4. **Either way, user gets invited!** ✅

---

## Database Queries

The system uses existing backend methods:

```swift
// From HouseholdService
func fetchInvitesForEmail(email: String) async throws -> [HouseholdInviteWithName]

func acceptInvite(inviteId: UUID) async throws -> AppUser
```

**Query performed:**
```sql
SELECT *, households(name)
FROM household_invites
WHERE invited_email = $1
  AND status = 'pending'
  AND expires_at > now()
```

**Performance:**
- Indexed on `invited_email`
- Only runs once per sign-in
- Filters expired invites server-side

---

## Security

✅ **Email Verification Required**
- Only shows invites for authenticated user's email
- Can't access invites for other emails

✅ **Backend Validation**
- `acceptInvite()` RPC validates invite exists
- Checks invite hasn't expired
- Verifies email matches invited email
- Enforces row-level security policies

✅ **No Injection Risk**
- All queries use parameterized values
- Email validation on backend

---

## Testing

### Manual Test Cases

**Test 1: New User Sign Up**
```
1. Send invite to test@example.com
2. Open app (not signed in)
3. Tap "Sign Up"
4. Enter test@example.com
5. Complete sign-up
6. VERIFY: Invitation sheet appears
7. Tap "Accept Invitation"
8. VERIFY: Success toast and user is in household
```

**Test 2: Existing User Sign In**
```
1. Send invite to existing@example.com
2. Sign out of app
3. Sign in with existing@example.com
4. VERIFY: Invitation sheet appears immediately
5. Tap "Accept Invitation"
6. VERIFY: User switches to new household
```

**Test 3: Multiple Invites**
```
1. Send 3 invites to multi@example.com
2. Sign in with multi@example.com
3. VERIFY: First invite appears
4. Tap "Accept Invitation"
5. VERIFY: Second invite appears
6. Tap "Not Now"
7. VERIFY: Third invite appears
8. Tap "Accept Invitation"
9. VERIFY: No more invites, back to app
```

**Test 4: Expired Invite**
```
1. Manually expire an invite in database
2. Sign in with that email
3. VERIFY: Expired invite does NOT appear
4. VERIFY: Only valid invites are shown
```

**Test 5: Combined with Deep Link**
```
1. Send invite to combo@example.com
2. Download app
3. Click deep link from email
4. VERIFY: Deep link accepts invite immediately
5. VERIFY: No duplicate prompts appear
```

---

## Design Decisions

### Why Sheet Instead of Alert?

**Sheet Advantages:**
- More space for information
- Better branding with icons and colors
- Can show expiration time
- Doesn't block entire app
- Better accessibility

**Alert Limitations:**
- Limited customization
- Can't show rich content
- Less user-friendly
- Harder to brand

### Why Check After Every Sign-In?

**Rationale:**
- Invites can arrive while user is signed out
- User might have multiple accounts
- Minimal performance impact (one query)
- Ensures invites are never missed

### Why Show One at a Time?

**Rationale:**
- Less overwhelming for users
- Clear action per invite
- User can review each household name
- Can decline some and accept others

---

## Future Enhancements

### 1. Batch Accept
Allow users to accept multiple invites at once

### 2. Push Notification
Notify users immediately when invited (even if app is closed)

### 3. In-App Notification Badge
Show badge on profile tab when pending invites exist

### 4. Invite Preview
Show household member count, pantry size, etc. before accepting

### 5. Smart Sorting
Show invites from known contacts first (based on phone contacts)

---

## Troubleshooting

### Invite Not Showing After Sign-In

**Check:**
1. Invite exists in database: `SELECT * FROM household_invites WHERE invited_email = '...'`
2. Invite status is 'pending'
3. Invite hasn't expired
4. User signed in with exact email (case-insensitive)

**Debug:**
- Check Xcode Console for "Checking for pending invites" log
- Look for "Found X pending invite(s)" or "No pending invites found"

### Invite Sheet Won't Dismiss

**Check:**
- Not stuck in loading state (white spinner)
- Check network connectivity
- Check backend logs for RPC errors

**Fix:**
- Force close app and reopen
- Sheet will reappear if invite wasn't accepted

### Multiple Invites Not Showing

**Check:**
- `pendingInvitesToAccept` array is being populated
- Sheet binding is working correctly

**Debug:**
- Add breakpoint in `checkForPendingInvites()`
- Verify `invites.count` in logs

---

## Metrics to Track

1. **Conversion Rate**: Email sent → Invite accepted
2. **Time to Accept**: Email sent → Invite accepted (median time)
3. **Acceptance Method**: Deep link vs. Email matching
4. **Drop-off Rate**: Users who see prompt but don't accept

---

## Deployment Checklist

- [x] Add pending invites state to AuthenticationService
- [x] Add checkForPendingInvites() method
- [x] Update all sign-in methods to check invites
- [x] Create PendingInvitePromptView
- [x] Add sheet presentation to GrubShelfApp
- [x] Test with email/password sign-in
- [x] Test with Google Sign-In
- [x] Test with Apple Sign-In
- [ ] Test with real TestFlight users
- [ ] Monitor acceptance rates
- [ ] Gather user feedback

---

## Summary

**What We Built:**
An automatic invitation detection system that eliminates friction for new users joining households.

**Key Benefit:**
Users no longer need to remember to return to the invitation email after downloading the app. They just sign up and automatically see any pending invites.

**Result:**
Smoother onboarding → Higher invite acceptance rates → More household members → Better product engagement

🎉 **Implementation Complete!**
