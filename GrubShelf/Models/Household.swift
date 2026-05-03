import Foundation

struct Household: Codable, Identifiable, Equatable, Sendable {
    let householdId: UUID
    var name: String
    var planType: String?
    let createdAt: Date

    var id: UUID { householdId }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case name
        case planType = "plan_type"
        case createdAt = "created_at"
    }
}
