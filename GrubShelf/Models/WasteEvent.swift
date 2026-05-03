import Foundation

enum WasteEventSource: String, Codable, Sendable {
    case manualRemoval = "manual_removal"
    case waste = "waste"
    case expired = "expired"
    case shoppingAudit = "shopping_audit"
}

struct WasteEvent: Codable, Identifiable, Equatable, Sendable {
    let eventId: UUID
    let householdId: UUID
    var pantryItemId: UUID?
    var itemName: String
    var date: Date
    var estimatedCostMinor: Int?
    var period: String
    var source: String

    var id: UUID { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case householdId = "household_id"
        case pantryItemId = "pantry_item_id"
        case itemName = "item_name"
        case date
        case estimatedCostMinor = "estimated_cost_minor"
        case period
        case source
    }
}
