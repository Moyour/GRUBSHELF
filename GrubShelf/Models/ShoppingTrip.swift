import Foundation

struct ShoppingTrip: Codable, Identifiable, Equatable, Sendable {
    let tripId: UUID
    let householdId: UUID
    var shoppingListId: UUID?
    var date: Date
    var totalCostMinor: Int?
    var itemCount: Int
    var period: String
    var costLogged: Bool

    var id: UUID { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case householdId = "household_id"
        case shoppingListId = "shopping_list_id"
        case date
        case totalCostMinor = "total_cost_minor"
        case itemCount = "item_count"
        case period
        case costLogged = "cost_logged"
    }
}
