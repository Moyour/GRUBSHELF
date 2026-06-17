import Foundation
import Observation
import os
import Supabase
import Auth
import GoogleSignIn

@Observable
final class AuthenticationService {
    var isAuthenticated = false
    var isCheckingSession = true
    var currentUser: AppUser?
    var isLoading = false
    var errorMessage: String?
    var pendingVerificationEmail: String?
    /// Email awaiting OTP verification during password reset.
    var pendingPasswordResetEmail: String?
    /// Set after recovery OTP is verified; user must call `update(password:)` before full sign-in.
    var mustCompletePasswordReset = false
    /// Pending household invites detected after sign-in/sign-up
    var pendingInvitesToAccept: [HouseholdInviteWithName] = []
    /// True while checking for pending invites after authentication
    var isCheckingForInvites = false
    /// True when the user explicitly typed their name (email sign-up/sign-in).
    /// OAuth sign-ins leave this false so the name confirmation gate shows.
    var didProvideNameManually = false

    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Auth")
    private let signInRateLimiter = RateLimiter(maxAttempts: 5, window: 60, persistenceKey: "GrubShelf.rateLimit.signIn")

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Session

    func checkSession() async {
        isCheckingSession = true
        do {
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id)
            isAuthenticated = currentUser != nil
        } catch {
            Self.logger.error("Session check failed: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
        }
        isCheckingSession = false
    }

    /// Force refresh the authentication session token
    func refreshSession() async throws {
        Self.logger.info("🔄 Attempting to refresh session...")
        let session = try await client.auth.refreshSession()
        await fetchUserProfile(userId: session.user.id)
        isAuthenticated = currentUser != nil
        Self.logger.info("✅ Session refreshed successfully")
    }

    /// Reloads `currentUser` from `public.users` (e.g. when opening Profile or
    /// during pull-to-refresh on Home). Uses a direct read of the existing row
    /// instead of the `ensure_user_profile` upsert so a refresh cannot replace
    /// a household-linked profile with a freshly-inserted household-less one.
    /// If the read returns nothing (brand-new sign-up where the row hasn't been
    /// provisioned yet) it falls back to the ensure path.
    func reloadUserProfileFromServer() async {
        do {
            let session = try await client.auth.session
            if let row = try await readUserRow(userId: session.user.id) {
                currentUser = Self.mergeReloadedProfile(existing: currentUser, reloaded: row)
            } else {
                Self.logger.notice("reloadUserProfileFromServer: user row missing, ensuring it exists")
                await ensureUserRowExists(userId: session.user.id)
            }
        } catch {
            Self.logger.warning(
                "Failed to reload user profile: \(error.localizedDescription, privacy: .public)"
            )
            // Session missing or read failed — leave currentUser as-is so a
            // transient network blip doesn't kick the user back to onboarding.
        }
    }

    /// Direct read of the authenticated user's row in `public.users`. Returns
    /// `nil` if the row doesn't exist yet so callers can decide whether to
    /// fall back to the ensure/upsert RPC path.
    private func readUserRow(userId: UUID) async throws -> AppUser? {
        let rows: [AppUser] = try await client
            .from("users")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Returns the reloaded profile, but preserves a previously-known household
    /// membership when the reload comes back with a `nil` `householdId` for the
    /// same user. Without this guard, a transient refresh result could drop the
    /// household and route the user back to `CreateHouseholdView` mid-session.
    static func mergeReloadedProfile(existing: AppUser?, reloaded: AppUser) -> AppUser {
        guard let existing, existing.userId == reloaded.userId else {
            return reloaded
        }
        guard reloaded.householdId == nil, existing.householdId != nil else {
            return reloaded
        }
        var merged = reloaded
        merged.householdId = existing.householdId
        merged.role = existing.role
        merged.isOwner = existing.isOwner
        return merged
    }

    // MARK: - Email/Password

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            Self.logger.info("📝 Starting sign up for email: \(email, privacy: .private)")
            let result = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(trimmedName)]
            )
            if let session = result.session {
                // Email confirmations disabled — user is already authenticated.
                Self.logger.info("✅ Sign up successful, fetching profile...")

                await fetchUserProfile(userId: session.user.id)
                // Pre-flip the invite-check flag BEFORE marking authenticated so the
                // routing in GrubShelfApp shows the "Checking for invitations…" view
                // instead of briefly flashing CreateHouseholdView while the async
                // invite lookup is in flight.
                didProvideNameManually = true
                isCheckingForInvites = true
                isAuthenticated = true

                Self.logger.info("🔎 Starting invitation check...")
                await checkForPendingInvites()
                Self.logger.info("✅ Sign up flow complete")
            } else {
                // Email confirmation required — user must enter the OTP code.
                Self.logger.info("📧 Email confirmation required")
                pendingVerificationEmail = email
            }
        } catch {
            Self.logger.error("❌ Sign up failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await signInRateLimiter.attempt()
            let session = try await client.auth.signIn(email: email, password: password)
            await fetchUserProfile(userId: session.user.id)
            // Flip both flags together so SwiftUI never sees authenticated=true
            // with isCheckingForInvites=false during the invite lookup. Without
            // this, the routing in GrubShelfApp briefly resolves to
            // CreateHouseholdView for new users who actually have an invite.
            didProvideNameManually = true
            isCheckingForInvites = true
            isAuthenticated = true
            await checkForPendingInvites()
        } catch let error as RateLimitError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Email Verification

    func verifyEmail(code: String) async {
        isLoading = true
        errorMessage = nil
        guard let email = pendingVerificationEmail else {
            errorMessage = "No pending verification."
            isLoading = false
            return
        }
        do {
            let response = try await client.auth.verifyOTP(
                email: email, token: code, type: .signup
            )
            let user: User
            switch response {
            case .session(let session): user = session.user
            case .user(let u): user = u
            }
            let name = user.userMetadata["name"]?.value as? String ?? email
            let rows: [AppUser] = try await client.rpc("ensure_user_profile", params: [
                "p_user_id": user.id.uuidString,
                "p_name": name,
                "p_email": email,
            ]).execute().value

            currentUser = rows.first
            pendingVerificationEmail = nil
            // Set the checking flag before flipping isAuthenticated so the routing
            // in GrubShelfApp shows "Checking for invitations…" rather than briefly
            // resolving to CreateHouseholdView while the invite lookup is in flight.
            didProvideNameManually = true
            isCheckingForInvites = true
            isAuthenticated = true
            await checkForPendingInvites()
        } catch {
            errorMessage = "Invalid or expired code. Please try again."
        }
        isLoading = false
    }

    func resendVerificationEmail() async {
        guard let email = pendingVerificationEmail else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await client.auth.resend(email: email, type: .signup)
            ToastManager.shared.show("Code resent to \(email)", style: .success)
        } catch {
            errorMessage = "Could not resend. Try again in a moment."
        }
        isLoading = false
    }

    // MARK: - Password Reset

    /// Check if a user signed up with OAuth providers (Apple/Google) by querying their identities
    func checkUserSignInMethod(email: String) async -> UserSignInMethod {
        do {
            // Query the auth.users table via admin API to check identities
            // Note: This requires the email to exist in the system
            let response = try await client.rpc("check_user_signin_provider", params: [
                "p_email": email
            ]).execute()
            
            let dataValue = response.data
            if let provider = String(data: dataValue, encoding: .utf8) {
                switch provider {
                case "apple":
                    return .apple
                case "google":
                    return .google
                case "email":
                    return .email
                default:
                    return .email
                }
            }
            return .email
        } catch {
            // If we can't determine, allow password reset attempt
            // (Supabase will handle if user doesn't exist)
            return .email
        }
    }

    func requestPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        
        // Check if user signed up with OAuth provider
        let signInMethod = await checkUserSignInMethod(email: email)
        
        switch signInMethod {
        case .apple:
            errorMessage = "This account uses Sign in with Apple. Please use the 'Sign in with Apple' button to access your account. Apple manages your account security."
            isLoading = false
            return
            
        case .google:
            errorMessage = "This account uses Google Sign-In. Please use the 'Continue with Google' button to access your account."
            isLoading = false
            return
            
        case .email:
            // Proceed with normal password reset
            break
        }
        
        do {
            Self.logger.info("Requesting password reset for \(email, privacy: .private)")
            try await client.auth.resetPasswordForEmail(email)
            pendingPasswordResetEmail = email
            Self.logger.info("Password reset request completed without error")
        } catch {
            Self.logger.error("Password reset failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not send reset email. Check the address and try again."
        }
        isLoading = false
    }
    
    enum UserSignInMethod {
        case apple
        case google
        case email
    }

    func verifyPasswordResetCode(code: String) async {
        isLoading = true
        errorMessage = nil
        guard let email = pendingPasswordResetEmail else {
            errorMessage = "No pending password reset."
            isLoading = false
            return
        }
        do {
            let response = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )
            let user: User
            switch response {
            case .session(let session): user = session.user
            case .user(let u): user = u
            }
            pendingPasswordResetEmail = nil
            mustCompletePasswordReset = true
            await fetchUserProfile(userId: user.id)
            if currentUser == nil {
                await ensureUserRowExists(userId: user.id)
            }
        } catch {
            errorMessage = "Invalid or expired code. Please try again."
        }
        isLoading = false
    }

    func resendPasswordResetCode() async {
        guard let email = pendingPasswordResetEmail else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await client.auth.resetPasswordForEmail(email)
            ToastManager.shared.show("Code resent to \(email)", style: .success)
        } catch {
            errorMessage = "Could not resend. Try again in a moment."
        }
        isLoading = false
    }

    func cancelPendingPasswordReset() {
        pendingPasswordResetEmail = nil
        errorMessage = nil
    }

    func submitNewPasswordAfterReset(password: String) async {
        guard mustCompletePasswordReset else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await client.auth.update(user: .init(password: password))
            mustCompletePasswordReset = false
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id)
            if currentUser == nil {
                await ensureUserRowExists(userId: session.user.id)
            }
            isAuthenticated = currentUser != nil
            ToastManager.shared.show("Password updated", style: .success)
        } catch {
            errorMessage =
                error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Could not update password. Try again." : error.localizedDescription
        }
    }

    func abandonPasswordResetFlow() async {
        mustCompletePasswordReset = false
        pendingPasswordResetEmail = nil
        errorMessage = nil
        await signOut()
    }

    // MARK: - Google Sign In

    /// Signs in with Google using the native GoogleSignIn SDK.
    /// Call from a view that has access to a UIViewController (e.g. via UIApplication.shared.keyWindow?.rootViewController).
    func signInWithGoogle(idToken: String, accessToken: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            let displayName = session.user.userMetadata["full_name"]?.value as? String
                ?? session.user.userMetadata["name"]?.value as? String
                ?? session.user.email
                ?? "User"
            let email = session.user.email ?? ""

            _ = try? await client.rpc("ensure_user_profile", params: [
                "p_user_id": session.user.id.uuidString,
                "p_name": displayName,
                "p_email": email,
            ]).execute()

            await fetchUserProfile(userId: session.user.id)

            // Flip the checking flag and authenticated flag in the same hop so
            // SwiftUI never observes authenticated=true with isCheckingForInvites=false
            // mid-flight (which would race to CreateHouseholdView).
            await MainActor.run {
                isCheckingForInvites = true
                isAuthenticated = true
            }
            await checkForPendingInvites()
        } catch {
            await MainActor.run {
                errorMessage = Self.googleSignInErrorMessage(for: error)
            }
        }
        await MainActor.run { isLoading = false }
    }

    private static func googleSignInErrorMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("unacceptable audience") {
            return """
            Google token audience mismatch. Add GOOGLE_WEB_CLIENT_ID (Web OAuth client) to Config.plist, \
            rebuild, and in Supabase → Authentication → Google enter both client IDs with the web ID first.
            """
        }
        return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Google sign-in failed. Please try again." : message
    }

    // MARK: - Apple Sign In

    /// - Parameters:
    ///   - idToken: Apple identity token from ASAuthorizationAppleIDCredential.identityToken
    ///   - nonce: Raw nonce string (same one whose SHA256 was passed to Apple's request). Required when the JWT payload includes a `nonce` claim; omit or pass `nil` only when the token has no `nonce` (GoTrue requires both or neither).
    ///   - fullName: Optional full name from credential.fullName (only provided on first sign-in)
    func signInWithApple(idToken: String, nonce: String?, fullName: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let tokenHasNonce = Self.idTokenPayloadContainsNonce(idToken)
            if tokenHasNonce, nonce == nil || nonce?.isEmpty == true {
                await MainActor.run {
                    errorMessage = "Sign in failed. Please try again."
                }
                await MainActor.run { isLoading = false }
                return
            }
            // Must match GoTrue: pass nonce only if the id_token includes a nonce claim.
            let nonceForAPI: String? = tokenHasNonce ? nonce : nil

            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonceForAPI)
            )

            // When we have full name from Apple (first sign-in only), ensure user profile is created/updated with it
            // before fetchUserProfile, so we don't get a generic "User" from ensureUserRowExists
            let displayName = fullName.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
                ?? (session.user.userMetadata["full_name"]?.value as? String)
                ?? session.user.email
                ?? "User"
            let email = session.user.email ?? ""

            _ = try? await client.rpc("ensure_user_profile", params: [
                "p_user_id": session.user.id.uuidString,
                "p_name": displayName,
                "p_email": email,
            ]).execute()

            await fetchUserProfile(userId: session.user.id)

            await MainActor.run {
                isCheckingForInvites = true
                isAuthenticated = true
            }
            await checkForPendingInvites()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        await MainActor.run { isLoading = false }
    }

    // MARK: - Update Profile

    func updateUserName(_ newName: String) async throws {
        guard let user = currentUser else { throw AuthError.noUser }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await client.from("users")
            .update(["name": trimmed, "updated_at": ISO8601DateFormatter.shared.string(from: .now)])
            .eq("user_id", value: user.userId.uuidString)
            .execute()

        currentUser?.name = trimmed
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Best-effort
        }
        isAuthenticated = false
        currentUser = nil
        mustCompletePasswordReset = false
        pendingPasswordResetEmail = nil
        isCheckingForInvites = false
        didProvideNameManually = false
        pendingInvitesToAccept = []
        ShoppingListWidgetToggleQueue.clear()
        ShoppingListWidgetDataStore.shared.clear()
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.noUser
        }

        // Audit log before deletion (while user still exists)
        _ = try? await client.rpc("log_audit_event", params: [
            "p_action": "delete_account",
            "p_target_entity": "users",
            "p_target_id": user.userId.uuidString,
        ]).execute()

        // Call Supabase RPC to delete all user data (pantry items, shopping lists,
        // transactions, waste events, finance settings, household membership, user row)
        try await client.rpc("delete_user_data", params: [
            "p_user_id": user.userId.uuidString,
        ]).execute()

        await signOut()
    }

    enum AuthError: LocalizedError {
        case noUser

        var errorDescription: String? {
            switch self {
            case .noUser: return "No authenticated user found."
            }
        }
    }

    // MARK: - Helpers

    /// Decodes the JWT payload (no signature verification) to see if Apple included a `nonce` claim.
    private static func idTokenPayloadContainsNonce(_ idToken: String) -> Bool {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return false }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padLength)
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nonce = json["nonce"] as? String
        else { return false }
        return !nonce.isEmpty
    }

    private func fetchUserProfile(userId: UUID) async {
        // Use RPC instead of direct table query to avoid RLS timing issues
        // after fresh sign-in when session might not be fully attached yet
        await ensureUserRowExists(userId: userId)
    }

    func ensureUserRowExists(userId: UUID) async {
        Self.logger.notice(
            "ensureUserRowExists starting for userId=\(userId.uuidString, privacy: .public)"
        )
        do {
            let session = try await client.auth.session
            let email = session.user.email ?? ""
            let name = session.user.userMetadata["name"]?.value as? String ?? email

            let rows: [AppUser] = try await client.rpc("ensure_user_profile", params: [
                "p_user_id": userId.uuidString,
                "p_name": name.isEmpty ? "User" : name,
                "p_email": email,
            ]).execute().value

            await MainActor.run {
                if let first = rows.first {
                    currentUser = Self.mergeReloadedProfile(existing: currentUser, reloaded: first)
                } else {
                    currentUser = nil
                }
            }
        } catch {
            Self.logger.error(
                "ensureUserRowExists failed for userId=\(userId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            await MainActor.run { currentUser = nil }
        }
    }
    
    // MARK: - Pending Invites
    
    /// Checks for pending household invites for the authenticated user's email.
    /// If found, populates `pendingInvitesToAccept` so the UI can prompt the user.
    func checkForPendingInvites() async {
        await MainActor.run {
            isCheckingForInvites = true
        }
        defer {
            Task { @MainActor in
                isCheckingForInvites = false
                Self.logger.info("🏁 Finished checking invites. isCheckingForInvites = false")
            }
        }

        guard let email = currentUser?.email else {
            Self.logger.warning("⚠️ checkForPendingInvites: no current user email")
            return
        }

        Self.logger.info("🔎 Checking for pending invites for email: \(email, privacy: .private)")
        Self.logger.info("👤 Current user ID: \(self.currentUser?.userId.uuidString ?? "unknown", privacy: .public)")
        Self.logger.info("🏠 Current household ID: \(self.currentUser?.householdId?.uuidString ?? "none", privacy: .public)")

        do {
            let householdService = HouseholdService(client: client)
            let invites = try await householdService.fetchInvitesForEmail(email: email)

            if !invites.isEmpty {
                Self.logger.info("🎉 Found \(invites.count) pending invite(s)!")
                await MainActor.run {
                    self.pendingInvitesToAccept = invites
                    Self.logger.info("✅ Set pendingInvitesToAccept array with \(self.pendingInvitesToAccept.count) invite(s)")
                }
            } else {
                Self.logger.warning("❌ No pending invites found for \(email, privacy: .private)")
            }
        } catch {
            Self.logger.error("❌ Failed to check pending invites: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Accepts a household invite and updates the current user.
    func acceptPendingInvite(inviteId: UUID) async throws {
        let householdService = HouseholdService(client: client)
        let updatedUser = try await householdService.acceptInvite(inviteId: inviteId)
        
        await MainActor.run {
            currentUser = updatedUser
            // Remove accepted invite from pending list
            pendingInvitesToAccept.removeAll { $0.inviteId == inviteId }
        }
        
        Self.logger.info("Successfully accepted invite: \(inviteId.uuidString, privacy: .public)")
    }
    
    /// Dismisses a pending invite without accepting it.
    func dismissPendingInvite(inviteId: UUID) {
        pendingInvitesToAccept.removeAll { $0.inviteId == inviteId }
    }
}

