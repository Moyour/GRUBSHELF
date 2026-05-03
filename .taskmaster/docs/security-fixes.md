# Security Fixes PRD - GrubShelf

## Overview
This document describes critical, high, and medium security vulnerabilities identified in the GrubShelf iOS application and Supabase backend. All issues must be resolved before production release.

## Priority Legend
- P0 = Critical (fix immediately)
- P1 = High (fix before release)
- P2 = Medium (fix soon after release)

---

## Task 1: Add .env to .gitignore and Rotate Exposed API Keys (P0 - CRITICAL)

### Problem
The `.env` file contains real `ANTHROPIC_API_KEY` and `GOOGLE_API_KEY` values but is NOT listed in `.gitignore`. These keys may already be committed to git history and exposed.

### Requirements
1. Add `.env`, `.env.*`, and `.env.local` patterns to `.gitignore`
2. Verify `.env` is not tracked by git (run `git rm --cached .env` if needed)
3. Scrub `.env` from git history using `git filter-branch` or BFG Repo Cleaner
4. Rotate both the `ANTHROPIC_API_KEY` and `GOOGLE_API_KEY` to new values
5. Update `.mcp.json` and any other config files referencing the old keys
6. Document in README that developers must create their own `.env` file with required keys

### Files to Modify
- `.gitignore`
- `.env` (rotate keys)
- `.mcp.json` (update if referencing old keys)

---

## Task 2: Fix Missing Authorization in delete_user_data RPC (P0 - CRITICAL)

### Problem
The `delete_user_data` Supabase RPC function accepts a `p_user_id` parameter but never verifies that `auth.uid()` matches `p_user_id`. Any authenticated user can delete ANY other user's account and all their data.

### Requirements
1. Add authorization check at the start of the `delete_user_data` function: `IF auth.uid() != p_user_id THEN RAISE EXCEPTION 'Unauthorized: can only delete own account'; END IF;`
2. Create a new migration file for this fix (do NOT modify the existing migration)
3. Test that a user can still delete their own account
4. Test that a user CANNOT delete another user's account
5. Consider adding audit logging before deletion

### Files to Modify
- New file: `supabase/migrations/XXX_fix_delete_user_auth.sql`

---

## Task 3: Fix Role Escalation in ensure_user_profile RPC (P0 - CRITICAL)

### Problem
The `ensure_user_profile` RPC function allows any authenticated user to set `p_role = 'admin'`, enabling privilege escalation. Any user can make themselves (or others) an admin.

### Requirements
1. Remove the `p_role` parameter from `ensure_user_profile` or hardcode it to `'member'` for new profiles
2. Create a separate `change_user_role` RPC that requires the caller to be an admin of the same household
3. In `change_user_role`: verify `auth.uid()` is an admin in the target user's household before allowing role changes
4. Prevent the last admin from being demoted (at least one admin must remain)
5. Create a new migration file for these changes

### Files to Modify
- New file: `supabase/migrations/XXX_fix_role_escalation.sql`
- `GrubShelf/Services/HouseholdService.swift` (update to use new RPC for role changes)

---

## Task 4: Remove Hardcoded Dev Credentials from Source Code (P0 - CRITICAL)

### Problem
`WelcomeView.swift` contains hardcoded dev credentials (`dev@grubshelf.test` / `devpassword123!`) in a `devSignIn()` function with DEBUG conditional. If DEBUG is accidentally left enabled in a release build, this creates an authentication bypass.

### Requirements
1. Remove all hardcoded email and password values from `WelcomeView.swift`
2. If a dev sign-in feature is needed, read credentials from a `DevConfig.plist` file that is in `.gitignore` and NOT included in release builds
3. Use `#if DEBUG` build configuration to completely exclude dev sign-in code from release builds
4. Verify that the dev sign-in button and all related code are stripped from release builds
5. Remove all `print()` debug statements that log user IDs or sensitive information (lines 128-135)

### Files to Modify
- `GrubShelf/Views/Auth/WelcomeView.swift`
- `.gitignore` (add DevConfig.plist)

---

## Task 5: Implement Rate Limiting on Authentication and RPC Endpoints (P1 - HIGH)

### Problem
No rate limiting exists on sign-up, sign-in, RPC calls, or invite creation. This enables brute force attacks, credential stuffing, and abuse.

### Requirements
1. Configure Supabase Auth rate limiting settings (if available via project settings)
2. Implement client-side rate limiting in `AuthenticationService.swift`: max 5 failed login attempts per minute, then exponential backoff (30s, 60s, 120s)
3. Show user-facing message when rate limited: "Too many attempts. Please wait X seconds."
4. Add rate limiting to `HouseholdService.inviteMember`: max 10 invites per hour
5. Add rate limiting to barcode lookup: max 30 lookups per minute
6. Store rate limit state in memory (resets on app restart is acceptable)

### Files to Modify
- `GrubShelf/Services/AuthenticationService.swift`
- `GrubShelf/Services/HouseholdService.swift`
- `GrubShelf/Services/OpenFoodFactsService.swift`
- New file: `GrubShelf/Services/RateLimiter.swift`

---

## Task 6: Enforce Household Member Limit at Database Level (P1 - HIGH)

### Problem
The 20-member household limit is only enforced in the `invite_member` RPC function, not at the database schema level. It can be bypassed if RLS is misconfigured or if members are added through other code paths.

### Requirements
1. Create a PostgreSQL trigger function that fires BEFORE INSERT or UPDATE on the `users` table
2. The trigger should check: if `NEW.household_id IS NOT NULL`, count existing users with that `household_id`, and reject if count >= 20
3. Create a new migration file for this trigger
4. Keep the existing RPC-level check as a first line of defense (belt and suspenders)
5. Test that the trigger fires correctly and prevents exceeding 20 members

### Files to Modify
- New file: `supabase/migrations/XXX_household_member_limit_trigger.sql`

---

## Task 7: Fix CSV Export Injection Vulnerability (P1 - HIGH)

### Problem
The `DataExportService.swift` CSV export includes user-controlled fields that could contain formula injection payloads (e.g., `=CMD()`, `+CMD()`, `-CMD()`, `@SUM()`). If exported CSV files are opened in Excel, malicious formulas could execute.

### Requirements
1. In the `escapeCSV` function, prefix any field starting with `=`, `+`, `-`, `@`, `\t`, or `\r` with a single quote (`'`) to prevent formula injection
2. Apply this sanitization to ALL user-controlled fields (item name, category, store name, etc.)
3. Add a comment explaining why the prefix is needed
4. Test with payloads like `=CMD("calc")`, `+CMD("calc")`, `-1+1`, `@SUM(1,2)`

### Files to Modify
- `GrubShelf/Services/DataExportService.swift`

---

## Task 8: Strengthen Password Policy (P2 - MEDIUM)

### Problem
The minimum password requirement is only 6 characters with no complexity requirements. This does not meet common security standards.

### Requirements
1. Increase minimum password length to 12 characters
2. Add a password strength indicator to the sign-up form (weak/medium/strong visual bar)
3. Require at least one uppercase letter, one lowercase letter, and one number
4. Update the validation message to clearly state requirements
5. Update `EmailAuthView.swift` with the new validation logic
6. Consider adding a "show password" toggle button

### Files to Modify
- `GrubShelf/Views/Auth/EmailAuthView.swift`
- New helper: password validation logic (can be added to existing file or extracted)

---

## Task 9: Implement TLS Certificate Pinning for API Calls (P2 - MEDIUM)

### Problem
API calls to external services (OpenFoodFacts, Supabase) do not use certificate pinning, making them vulnerable to man-in-the-middle attacks on untrusted networks.

### Requirements
1. Create a custom `URLSessionDelegate` that implements `urlSession(_:didReceive:completionHandler:)` for certificate pinning
2. Pin certificates for the Supabase project URL
3. Pin certificates for `world.openfoodfacts.org`
4. Store pinned certificate hashes in a constants file
5. Include backup pins (next certificate in the chain) to handle certificate rotation
6. Implement graceful fallback: if pinning fails, show an error to the user rather than silently failing
7. Set minimum TLS version to 1.2

### Files to Modify
- `GrubShelf/Services/OpenFoodFactsService.swift`
- `GrubShelf/Services/SupabaseManager.swift` (or equivalent)
- New file: `GrubShelf/Services/CertificatePinning.swift`

---

## Task 10: Add Audit Logging for Critical Operations (P2 - MEDIUM)

### Problem
No audit trail exists for critical operations (account deletion, role changes, member removal, data exports). This makes incident investigation impossible and creates compliance concerns.

### Requirements
1. Create an `audit_logs` table in Supabase: `id (UUID PK)`, `user_id (UUID)`, `household_id (UUID)`, `action (TEXT)`, `target_entity (TEXT)`, `target_id (UUID)`, `metadata (JSONB)`, `created_at (TIMESTAMPTZ)`
2. Enable RLS on `audit_logs` — users can only read logs for their own household, only the system can write
3. Log these actions: account_deleted, role_changed, member_removed, member_invited, data_exported, household_created, household_deleted
4. Add audit logging calls in the relevant RPC functions and Swift services
5. Create a migration file for the table and policies

### Files to Modify
- New file: `supabase/migrations/XXX_audit_logs.sql`
- `GrubShelf/Services/HouseholdService.swift` (add audit calls)
- `GrubShelf/Services/DataExportService.swift` (add audit call on export)
- `GrubShelf/Services/AuthenticationService.swift` (add audit call on delete)

---

## Task 11: Secure Barcode Input and URL Construction (P2 - MEDIUM)

### Problem
Barcode values are interpolated directly into URL strings instead of using `URLComponents`. While basic length validation exists, this pattern is fragile and could allow URL injection if validation is bypassed.

### Requirements
1. Refactor `OpenFoodFactsService.swift` to use `URLComponents` and `URLQueryItem` instead of string interpolation for URL construction
2. Validate that barcode contains only numeric characters (0-9) before making the request
3. Add stricter input sanitization
4. Add rate limiting (covered in Task 5, but ensure coordination)

### Files to Modify
- `GrubShelf/Services/OpenFoodFactsService.swift`

---

## Task 12: Remove Debug Print Statements and Secure Logging (P2 - MEDIUM)

### Problem
Multiple `print()` statements log sensitive information including user IDs. These statements may not be stripped from release builds and create information disclosure risks.

### Requirements
1. Replace ALL `print()` statements throughout the codebase with `os.Logger` (Apple's structured logging framework)
2. Use appropriate log levels: `.debug` for development info, `.info` for operational events, `.error` for errors
3. Ensure no PII (user IDs, emails, names) is logged at `.info` level or above
4. Verify that `.debug` level logs are automatically excluded from release builds
5. Create a centralized `AppLogger` utility for consistent logging across the app

### Files to Modify
- `GrubShelf/Views/Auth/WelcomeView.swift`
- Any other files containing `print()` statements
- New file: `GrubShelf/Services/AppLogger.swift`
