import Foundation

struct AppUser: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    var name: String
    var email: String
    var householdId: UUID?
    var role: UserRole
    var isOwner: Bool
    var emailNotificationsEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case householdId = "household_id"
        case role
        case isOwner = "is_owner"
        case emailNotificationsEnabled = "email_notifications_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        userId: UUID,
        name: String,
        email: String,
        householdId: UUID? = nil,
        role: UserRole,
        isOwner: Bool = false,
        emailNotificationsEnabled: Bool = true,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.userId = userId
        self.name = name
        self.email = email
        self.householdId = householdId
        self.role = role
        self.isOwner = isOwner
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        householdId = try container.decodeIfPresent(UUID.self, forKey: .householdId)
        role = try container.decode(UserRole.self, forKey: .role)
        isOwner = try container.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        emailNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .emailNotificationsEnabled) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum UserRole: String, Codable, Sendable {
    case admin
    case member
    case guest
}

extension AppUser {
    /// Canonical ordering for household member lists:
    /// 1. The household owner (creator) always appears first.
    /// 2. Other admins follow, ordered alphabetically by name.
    /// 3. Regular members (or any non-admin role) come last, alphabetically.
    ///
    /// When applied to a single-role slice (e.g. only admins) the owner-first
    /// guarantee still holds, so this is safe to reuse across the grouped
    /// FamilyMembersView sections and the flat ProfileView Family section.
    static let householdOrder: (AppUser, AppUser) -> Bool = { lhs, rhs in
        if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
        let lhsRank = lhs.role == .admin ? 0 : 1
        let rhsRank = rhs.role == .admin ? 0 : 1
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
