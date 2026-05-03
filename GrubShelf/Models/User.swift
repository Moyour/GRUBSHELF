import Foundation

struct AppUser: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    var name: String
    var email: String
    var householdId: UUID?
    var role: UserRole
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
        case emailNotificationsEnabled = "email_notifications_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        householdId = try container.decodeIfPresent(UUID.self, forKey: .householdId)
        role = try container.decode(UserRole.self, forKey: .role)
        emailNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .emailNotificationsEnabled) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum UserRole: String, Codable, Sendable {
    case admin
    case member
}
