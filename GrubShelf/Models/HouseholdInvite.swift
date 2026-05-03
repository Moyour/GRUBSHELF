import Foundation

struct HouseholdInvite: Codable, Identifiable, Equatable, Sendable {
    let inviteId: UUID
    let householdId: UUID
    let invitedEmail: String
    let invitedBy: UUID
    var status: InviteStatus
    let createdAt: Date
    let expiresAt: Date

    var id: UUID { inviteId }

    var isExpired: Bool {
        expiresAt < .now
    }

    enum InviteStatus: String, Codable, Sendable {
        case pending
        case accepted
        case cancelled
    }

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
        case householdId = "household_id"
        case invitedEmail = "invited_email"
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct HouseholdInviteWithName: Codable, Identifiable, Equatable, Sendable {
    let inviteId: UUID
    let householdId: UUID
    let invitedEmail: String
    let invitedBy: UUID
    var status: HouseholdInvite.InviteStatus
    let createdAt: Date
    let expiresAt: Date
    let households: HouseholdNameRef

    struct HouseholdNameRef: Codable, Equatable, Sendable {
        let name: String
    }

    var id: UUID { inviteId }
    var householdName: String { households.name }
    var isExpired: Bool { expiresAt < .now }

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
        case householdId = "household_id"
        case invitedEmail = "invited_email"
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case households
    }
}
