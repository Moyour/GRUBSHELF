# Deep Linking Implementation for Household Invitations

## Overview

The GrubShelf app now supports deep linking for household invitations. When users receive an invitation email, they can tap a link that automatically opens the app and accepts the invitation, providing a seamless onboarding experience.

## How It Works

### 1. Email Invitation Flow

When an admin invites a member to their household:

1. An invitation is created in the database with a unique `invite_id` (UUID)
2. An email is sent to the invited user containing:
   - A primary deep link: `grubshelf://invite?token={invite_id}`
   - A secondary TestFlight download link for new users

### 2. Deep Link Format

**Primary Link (for existing users):**
```
grubshelf://invite?token=<invite_id>
```

**Example:**
```
grubshelf://invite?token=123e4567-e89b-12d3-a456-426614174000
```

### 3. User Experience Scenarios

#### Scenario A: User Already Has the App & Is Signed In
1. User taps "Accept Invitation" button in email
2. App opens via deep link
3. Invitation is automatically accepted
4. User sees success toast and is added to the household

#### Scenario B: User Has the App But Not Signed In
1. User taps "Accept Invitation" button in email
2. App opens via deep link
3. App prompts user to sign in
4. After sign-in, invitation is automatically accepted
5. User sees success toast and is added to the household

#### Scenario C: User Doesn't Have the App
1. User sees "Don't have GrubShelf yet?" message in email
2. User taps "Download the TestFlight Beta" link
3. User downloads and installs the app from TestFlight
4. User returns to email and taps "Accept Invitation"
5. App opens and follows Scenario B flow

## Technical Implementation

### Email Template Changes

**Files Modified:**
- `supabase/functions/send-household-invite/invite_email.ts`
- `supabase/functions/send-household-invite/index.ts`
- `supabase/functions/send-household-invite/invite_email_test.ts`

**Key Changes:**
1. Added `inviteId` parameter to email template functions
2. Generated deep link: `grubshelf://invite?token={inviteId}`
3. Updated email copy to guide both existing and new users
4. Included TestFlight download link as secondary action

### iOS App Changes

**Files Created:**
- `GrubShelf/Utilities/DeepLinkHandler.swift` - Parses deep link URLs

**Files Modified:**
- `GrubShelf/GrubShelfApp.swift` - Handles deep link navigation and invite acceptance

**Key Changes:**

1. **DeepLinkHandler** - Parses incoming URLs:
   ```swift
   enum DeepLink {
       case invite(token: UUID)
       case unknown
   }
   
   static func parse(_ url: URL) -> DeepLink
   ```

2. **GrubShelfApp** - Manages deep link flow:
   - Added `@State private var pendingInviteToken: UUID?` to track invites
   - Updated `.onOpenURL` handler to parse and handle invite links
   - Added `handleInviteDeepLink(token:)` method
   - Added `acceptPendingInvite(token:)` method
   - Integrated with existing `HouseholdService.acceptInvite()` method

### Deep Link URL Scheme

The app is already configured to handle the `grubshelf://` URL scheme in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.grubshelf.auth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>grubshelf</string>
        </array>
    </dict>
</array>
```

## Testing

### Manual Testing Steps

1. **Test with existing signed-in user:**
   - Have a test account signed in
   - Create an invitation from another account
   - Copy the invite link from the email (or database)
   - Paste in Safari: `grubshelf://invite?token={your-invite-id}`
   - Verify app opens and invitation is accepted

2. **Test with signed-out user:**
   - Sign out of the app
   - Tap invitation link
   - Verify app prompts for sign-in
   - Sign in with the invited email
   - Verify invitation is accepted after sign-in

3. **Test email flow:**
   - Send a real invitation via the app
   - Open email on device with GrubShelf installed
   - Tap "Accept Invitation" button
   - Verify proper flow

4. **Test new user flow:**
   - Uninstall app (or use device without app)
   - Open invitation email
   - Tap "Download the TestFlight Beta"
   - Install app from TestFlight
   - Return to email and tap "Accept Invitation"
   - Sign in and verify invitation is accepted

### Unit Tests

Run the Supabase Edge Function tests:

```bash
cd supabase/functions/send-household-invite
deno test invite_email_test.ts
```

Expected results:
- ✓ Email content includes deep link with invite token
- ✓ Email properly escapes HTML/XSS content
- ✓ Plain text version includes proper links

## Security Considerations

1. **Token Validation:**
   - Invite tokens are UUIDs stored in the database
   - The `acceptInvite` RPC validates the token server-side
   - Expired invitations are rejected
   - Only pending invitations can be accepted

2. **Authentication Required:**
   - Users must be signed in to accept invitations
   - The email address must match the invited email
   - Backend enforces email matching via RLS policies

3. **No Sensitive Data in URL:**
   - Only the invite UUID is included in the deep link
   - Household names, inviter info, etc. are fetched server-side
   - Links can be safely shared or forwarded

## Future Enhancements

1. **Universal Links** (iOS 9+):
   - Configure `apple-app-site-association` file
   - Create fallback web page at `https://grubshelf.com/invite/{token}`
   - Automatically redirect to app if installed, otherwise show instructions
   - Provides better UX and works without prompts

2. **Android Support:**
   - Implement deep linking for Android app
   - Use same URL scheme for cross-platform consistency

3. **Email Personalization:**
   - Show inviter's name and photo in email
   - Include household description/icon
   - Preview household stats (member count, pantry items, etc.)

4. **Smart Link Handling:**
   - Detect if app is installed before opening
   - Show "Open in App" banner on web fallback page
   - Track conversion metrics (email open → app install → invite accepted)

## Troubleshooting

### Deep Link Not Opening App

1. **Check URL scheme configuration:**
   - Verify `grubshelf` scheme is in Info.plist
   - Rebuild app after any Info.plist changes

2. **Test from Safari:**
   - Paste deep link directly in Safari
   - iOS may block deep links from some email clients

3. **Check logs:**
   - Open Xcode Console
   - Filter for "DeepLink" subsystem
   - Look for parsing errors

### Invitation Not Accepting

1. **Check authentication:**
   - Verify user is signed in with correct email
   - Check that `authService.currentUser` is populated

2. **Check invite status:**
   - Query database to verify invite is pending
   - Check expiration date hasn't passed
   - Verify invited email matches signed-in user

3. **Check logs:**
   - Look for error messages in toast notifications
   - Check backend logs for RPC errors

### Email Link Not Working

1. **Check Edge Function:**
   - Verify function is deployed
   - Check function logs for errors
   - Test function directly with curl

2. **Check email delivery:**
   - Verify Resend API key is configured
   - Check Resend dashboard for delivery status
   - Test with different email providers

## Deployment Checklist

- [ ] Deploy updated Edge Function
- [ ] Build and test iOS app with deep linking
- [ ] Submit TestFlight build
- [ ] Test email delivery end-to-end
- [ ] Update app screenshots if needed
- [ ] Monitor error logs after rollout
- [ ] Gather user feedback on invite flow

## Support

For questions or issues with deep linking:
1. Check Xcode Console logs (filter: "DeepLink")
2. Review Edge Function logs in Supabase Dashboard
3. Test with known-good invite tokens
4. Verify URL scheme configuration in Info.plist
