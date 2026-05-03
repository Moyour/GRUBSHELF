import Foundation

/// Parameter keys and builders for Supabase `users` profile RPCs used at onboarding.
enum UserProfileRPC {
    static let ensureUserProfileFunctionName = "ensure_user_profile"
    static let setSelfAdminForHouseholdFunctionName = "set_self_admin_for_household"

    /// Keys sent to `ensure_user_profile` (must match SQL; do not add `p_role`).
    static func ensureUserProfileParams(
        userId: UUID,
        name: String,
        email: String,
        householdId: UUID
    ) -> [String: String] {
        [
            "p_user_id": userId.uuidString,
            "p_name": name,
            "p_email": email,
            "p_household_id": householdId.uuidString,
        ]
    }
}
