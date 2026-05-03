import Foundation
import os
import Supabase

final class HouseholdService {
    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Household")
    private let inviteRateLimiter = RateLimiter(maxAttempts: 10, window: 3600)

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
        try await client.from("users")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .execute()
            .value
    }

    func updateMemberRole(userId: UUID, role: UserRole) async throws {
        try await client.rpc("change_user_role", params: [
            "p_target_user_id": userId.uuidString,
            "p_new_role": role.rawValue,
        ]).execute()

        // Audit log
        do {
            try await client.rpc("log_audit_event", params: [
                "p_action": "change_member_role",
                "p_target_entity": "users",
                "p_target_id": userId.uuidString,
                "p_metadata": "{\"new_role\": \"\(role.rawValue)\"}",
            ]).execute()
        } catch {
            Self.logger.error("Audit log failed (change_member_role): \(error.localizedDescription, privacy: .public)")
        }
    }

    func removeMember(userId: UUID) async throws {
        struct NullHousehold: Encodable {
            let household_id: String? = nil
        }
        try await client.from("users")
            .update(NullHousehold())
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Audit log
        do {
            try await client.rpc("log_audit_event", params: [
                "p_action": "remove_member",
                "p_target_entity": "users",
                "p_target_id": userId.uuidString,
            ]).execute()
        } catch {
            Self.logger.error("Audit log failed (remove_member): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Invites

    @discardableResult
    func inviteMember(email: String, householdId: UUID, invitedBy: UUID) async throws -> HouseholdInvite {
        try await inviteRateLimiter.attempt()

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard Self.isValidEmail(trimmed) else {
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

        await sendHouseholdInviteEmail(inviteId: created.inviteId)

        return created
    }

    /// Best-effort: Edge Function sends via Resend. Invite row already exists if this fails.
    private func sendHouseholdInviteEmail(inviteId: UUID) async {
        struct SendHouseholdInviteResponse: Decodable {
            let ok: Bool?
        }

        do {
            let _: SendHouseholdInviteResponse = try await client.functions.invoke(
                "send-household-invite",
                options: FunctionInvokeOptions(body: HouseholdInviteEmailPayload(inviteId: inviteId.uuidString))
            )
        } catch {
            Self.logger.error("send-household-invite Edge Function failed: \(String(describing: error), privacy: .public)")
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

        let invites: [HouseholdInviteWithName] = try await client.from("household_invites")
            .select("*, households(name)")
            .eq("invited_email", value: trimmed)
            .eq("status", value: "pending")
            .execute()
            .value

        return invites.filter { !$0.isExpired }
    }

    func acceptInvite(inviteId: UUID) async throws -> AppUser {
        let rows: [AppUser] = try await client.rpc("accept_household_invite", params: [
            "p_invite_id": inviteId.uuidString,
        ]).execute().value

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

    // MARK: - Helpers

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
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
        case .inviteCreationFailed: "Invite was sent but could not be confirmed. Pull to refresh the list."
        }
    }
}
