import Foundation

struct AppUser: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    var name: String
    var email: String
    var householdId: UUID?
    var role: UserRole
    let createdAt: Date
    var updatedAt: Date

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case householdId = "household_id"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum UserRole: String, Codable, Sendable {
    case admin
    case member
}
