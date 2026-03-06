import Foundation
import Supabase

final class HouseholdService {
    private let client: SupabaseClient

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
        try await client.from("users")
            .update(["role": role.rawValue])
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func removeMember(userId: UUID) async throws {
        struct NullHousehold: Encodable {
            let household_id: String? = nil
        }
        try await client.from("users")
            .update(NullHousehold())
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Invites

    func inviteMember(email: String, householdId: UUID, invitedBy: UUID) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard Self.isValidEmail(trimmed) else {
            throw InviteError.invalidEmail
        }

        let _: [HouseholdInvite] = try await client.rpc("create_household_invite", params: [
            "p_household_id": householdId.uuidString,
            "p_invited_email": trimmed,
            "p_invited_by": invitedBy.uuidString,
        ]).execute().value
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

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "Please enter a valid email address."
        case .householdFull: "This household has reached the 20-member limit."
        case .alreadyMember: "This person is already a member of your household."
        case .alreadyInvited: "An invite has already been sent to this email."
        case .acceptFailed: "Failed to accept the invite. Please try again."
        }
    }
}
