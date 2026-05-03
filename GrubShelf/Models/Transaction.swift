import Foundation

struct Transaction: Codable, Identifiable, Equatable, Sendable {
    let transactionId: UUID
    let householdId: UUID
    var itemId: UUID?
    var quantityPurchased: Double
    var totalCostMinor: Int
    var costPerUnitMinor: Int
    var purchaseDate: Date
    var storeName: String?

    var id: UUID { transactionId }

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case householdId = "household_id"
        case itemId = "item_id"
        case quantityPurchased = "quantity_purchased"
        case totalCostMinor = "total_cost_minor"
        case costPerUnitMinor = "cost_per_unit_minor"
        case purchaseDate = "purchase_date"
        case storeName = "store_name"
    }
}
