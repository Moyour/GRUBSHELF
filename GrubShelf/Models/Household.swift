import Foundation

struct Household: Codable, Identifiable, Equatable, Sendable {
    let householdId: UUID
    var name: String
    var planType: String?
    var currentPlanId: UUID?
    let createdAt: Date

    var id: UUID { householdId }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case name
        case planType = "plan_type"
        case currentPlanId = "current_plan_id"
        case createdAt = "created_at"
    }
}
