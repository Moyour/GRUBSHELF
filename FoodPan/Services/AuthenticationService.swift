import Foundation
import Observation
import Supabase
import AuthenticationServices
import GoogleSignIn

@Observable
final class AuthenticationService {
    var isAuthenticated = false
    var isCheckingSession = true
    var currentUser: AppUser?
    var isLoading = false
    var errorMessage: String?

    private let client: SupabaseClient

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

    // MARK: - Email/Password

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            let userId = response.user.id

            let rows: [AppUser] = try await client.rpc("ensure_user_profile", params: [
                "p_user_id": userId.uuidString,
                "p_name": name,
                "p_email": email,
            ]).execute().value

            isAuthenticated = true
            currentUser = rows.first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            isAuthenticated = true
            await fetchUserProfile(userId: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
    ///   - nonce: Raw nonce string (same one whose SHA256 was passed to Apple's request)
    ///   - fullName: Optional full name from credential.fullName (only provided on first sign-in)
    func signInWithApple(idToken: String, nonce: String, fullName: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )

            // When we have full name from Apple (first sign-in only), ensure user profile is created/updated with it
            // before fetchUserProfile, so we don't get a generic "User" from ensureUserRowExists
            let displayName = fullName?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? fullName!
                : (session.user.userMetadata["full_name"]?.value as? String)
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
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.noUser
        }

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
            // User row missing (e.g. DB was reset) — recreate from auth session
            await ensureUserRowExists(userId: userId)
        }
    }

    func ensureUserRowExists(userId: UUID) async {
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
            currentUser = nil
        }
    }
}
