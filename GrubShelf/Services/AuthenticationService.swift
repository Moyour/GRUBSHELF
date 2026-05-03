import Foundation
import Observation
import os
import Supabase
import Auth
import AuthenticationServices
import GoogleSignIn

@Observable
final class AuthenticationService {
    var isAuthenticated = false
    var isCheckingSession = true
    var currentUser: AppUser?
    var isLoading = false
    var errorMessage: String?
    var pendingVerificationEmail: String?
    /// Set after opening the email reset link while the recovery session waits for `update(password:)`.
    var mustCompletePasswordReset = false

    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Auth")
    private let signInRateLimiter = RateLimiter(maxAttempts: 5, window: 60)

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
            isAuthenticated = false
            currentUser = nil
        }
        isCheckingSession = false
    }

    /// Reloads `currentUser` from `public.users` (e.g. when opening Profile).
    func reloadUserProfileFromServer() async {
        do {
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id)
        } catch {
            // Session missing — leave currentUser as-is
        }
    }

    // MARK: - Email/Password

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(trimmedName)]
            )
            // Email confirmation is required — don't authenticate yet.
            // The user must enter the OTP code sent to their email.
            pendingVerificationEmail = email
        } catch {
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
            isAuthenticated = true
            await fetchUserProfile(userId: session.user.id)
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

            isAuthenticated = true
            currentUser = rows.first
            pendingVerificationEmail = nil
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

    func requestPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            Self.logger.info("Requesting password reset for \(email, privacy: .private)")
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: PasswordResetCallbackURL.redirectURL
            )
            Self.logger.info("Password reset request completed without error")
        } catch {
            Self.logger.error("Password reset failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not send reset email. Check the address and try again."
        }
        isLoading = false
    }

    func handlePasswordResetDeepLink(url: URL) async {
        guard PasswordResetCallbackURL.matches(url) else { return }
        guard SupabaseManager.shared.isConfigured else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await client.auth.session(from: url)
            mustCompletePasswordReset = true
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id)
            if currentUser == nil {
                await ensureUserRowExists(userId: session.user.id)
            }
            isAuthenticated = currentUser != nil
        } catch {
            errorMessage =
                "This reset link is invalid or expired. Go back and request a new password reset email."
            mustCompletePasswordReset = false
        }
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

    func abandonPasswordResetAfterLinkFlow() async {
        mustCompletePasswordReset = false
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

            await MainActor.run { isAuthenticated = true }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        await MainActor.run { isLoading = false }
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

            await MainActor.run { isAuthenticated = true }
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
            .update(["name": trimmed, "updated_at": ISO8601DateFormatter().string(from: .now)])
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
        do {
            let user: AppUser = try await client.from("users")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            currentUser = user
        } catch {
            Self.logger.warning(
                "fetchUserProfile failed for userId=\(userId.uuidString, privacy: .public); will ensureUserRowExists — error: \(error.localizedDescription, privacy: .public)"
            )
            // User row missing (e.g. DB was reset) — recreate from auth session
            await ensureUserRowExists(userId: userId)
        }
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

            currentUser = rows.first
        } catch {
            Self.logger.error(
                "ensureUserRowExists failed for userId=\(userId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            currentUser = nil
        }
    }
}
