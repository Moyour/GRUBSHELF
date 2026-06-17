import Foundation
import os
import Supabase

final class HouseholdService {
    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Household")
    private let inviteRateLimiter = RateLimiter(maxAttempts: 10, window: 3600, persistenceKey: "GrubShelf.rateLimit.invite")

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Household

    func fetchHousehold(id: UUID) async throws -> Household {
        try await client.from("households")
            .select()
            .eq("household_id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func updateHouseholdName(id: UUID, name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await client.from("households")
            .update(["name": trimmed])
            .eq("household_id", value: id.uuidString)
            .execute()
    }

    // MARK: - Members

    func fetchMembers(householdId: UUID) async throws -> [AppUser] {
        // Use RPC to bypass RLS issues after fresh sign-in
        try await client.rpc("fetch_household_members", params: [
            "p_household_id": householdId.uuidString
        ]).execute().value
    }

    func updateMemberRole(userId: UUID, role: UserRole) async throws {
        try await client.rpc("change_user_role", params: [
            "p_target_user_id": userId.uuidString,
            "p_new_role": role.rawValue,
        ]).execute()
    }

    func removeMember(userId: UUID, reason: String? = nil) async throws {
        struct RemoveMemberParams: Encodable {
            let p_user_id: String
            let p_reason: String?
            let p_handle_pending_items: String
        }
        try await client.rpc(
            "remove_household_member",
            params: RemoveMemberParams(
                p_user_id: userId.uuidString,
                p_reason: reason,
                p_handle_pending_items: "keep"
            )
        ).execute()
    }

    func transferOwnership(to userId: UUID) async throws {
        try await client.rpc("transfer_ownership", params: [
            "p_new_owner_id": userId.uuidString,
        ]).execute()
    }

    // MARK: - Invites

    struct InviteResult {
        let invite: HouseholdInvite
        let emailDelivered: Bool
        let usedResendOnboardingSender: Bool
    }

    @discardableResult
    func inviteMember(email: String, householdId: UUID, invitedBy: UUID) async throws -> InviteResult {
        try await inviteRateLimiter.attempt()

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard trimmed.isValidEmail else {
            throw InviteError.invalidEmail
        }

        let rows: [HouseholdInvite] = try await client.rpc("create_household_invite", params: [
            "p_household_id": householdId.uuidString,
            "p_invited_email": trimmed,
            "p_invited_by": invitedBy.uuidString,
        ]).execute().value

        guard let created = rows.first else {
            throw InviteError.inviteCreationFailed
        }

        // Audit log
        do {
            try await client.rpc("log_audit_event", params: [
                "p_action": "invite_member",
                "p_target_entity": "household_invites",
                "p_metadata": "{\"invited_email\": \"\(trimmed)\"}",
            ]).execute()
        } catch {
            Self.logger.error("Audit log failed (invite_member): \(error.localizedDescription, privacy: .public)")
        }

        let emailOutcome = await sendHouseholdInviteEmail(inviteId: created.inviteId)

        return InviteResult(
            invite: created,
            emailDelivered: emailOutcome.delivered,
            usedResendOnboardingSender: emailOutcome.usedResendOnboardingSender
        )
    }

    /// Internal result from the `send-household-invite` Edge Function call.
    private struct InviteEmailSendOutcome: Sendable {
        let delivered: Bool
        let usedResendOnboardingSender: Bool
    }

    private func sendHouseholdInviteEmail(inviteId: UUID) async -> InviteEmailSendOutcome {
        do {
            let response: SendHouseholdInviteAPIResponse = try await client.functions.invoke(
                "send-household-invite",
                options: FunctionInvokeOptions(body: HouseholdInviteEmailPayload(inviteId: inviteId.uuidString)),
                decode: { data, _ in
                    try JSONDecoder().decode(SendHouseholdInviteAPIResponse.self, from: data)
                }
            )
            let delivered = response.ok == true
            let onboarding = response.usesResendOnboardingSender
            return InviteEmailSendOutcome(delivered: delivered, usedResendOnboardingSender: onboarding)
        } catch {
            var httpCode = ""
            if case let FunctionsError.httpError(code, _) = error {
                httpCode = String(code)
            } else if case FunctionsError.relayError = error {
                httpCode = "relay"
            }
            Self.logger.error(
                "send-household-invite Edge Function failed (http=\(httpCode, privacy: .public)): \(String(describing: error), privacy: .public)"
            )
            return InviteEmailSendOutcome(delivered: false, usedResendOnboardingSender: false)
        }
    }

    func fetchPendingInvites(householdId: UUID) async throws -> [HouseholdInvite] {
        try await client.from("household_invites")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchInvitesForEmail(email: String) async throws -> [HouseholdInviteWithName] {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Self.logger.info("🔍 Fetching invites for email: \(trimmed, privacy: .private)")

        // Query for both 'pending' and 'approved' status invites
        let invites: [HouseholdInviteWithName] = try await client.from("household_invites")
            .select("*, households(name)")
            .eq("invited_email", value: trimmed)
            .in("status", values: ["pending", "approved"])
            .execute()
            .value

        Self.logger.info("📬 Found \(invites.count) raw invite(s) from database")

        if !invites.isEmpty {
            for invite in invites {
                Self.logger.info("  📧 Invite: email=\(invite.invitedEmail), status=\(invite.status.rawValue), expires=\(invite.expiresAt), expired=\(invite.isExpired)")
            }
        }

        let activeInvites = invites.filter { !$0.isExpired }
        Self.logger.info("✅ \(activeInvites.count) active (non-expired) invite(s)")

        return activeInvites
    }

    /// Fetch invite details by invite token (invite_id)
    func fetchInviteByToken(inviteToken: UUID) async throws -> HouseholdInviteWithName {
        try await client.from("household_invites")
            .select("*, households(name)")
            .eq("invite_id", value: inviteToken.uuidString)
            .in("status", values: ["pending", "approved"])
            .single()
            .execute()
            .value
    }

    func acceptInvite(inviteId: UUID) async throws -> AppUser {
        let rows: [AppUser] = try await withRetry { [client] in
            try await client.rpc("accept_household_invite", params: [
                "p_invite_id": inviteId.uuidString,
            ]).execute().value
        }

        guard let user = rows.first else {
            throw InviteError.acceptFailed
        }
        return user
    }

    func cancelInvite(inviteId: UUID) async throws {
        try await client.from("household_invites")
            .update(["status": "cancelled"])
            .eq("invite_id", value: inviteId.uuidString)
            .execute()
    }

}

enum InviteError: LocalizedError {
    case invalidEmail
    case householdFull
    case alreadyMember
    case alreadyInvited
    case acceptFailed
    case inviteCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "Please enter a valid email address."
        case .householdFull: "This household has reached the 20-member limit."
        case .alreadyMember: "This person is already a member of your household."
        case .alreadyInvited: "An invite has already been sent to this email."
        case .acceptFailed: "Failed to accept the invite. Please try again."
        case .inviteCreationFailed: "Could not create the invite. Please try again."
        }
    }
}
