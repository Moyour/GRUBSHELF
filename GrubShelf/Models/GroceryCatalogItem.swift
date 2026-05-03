import Foundation

struct GroceryCatalogItem: Codable, Identifiable, Equatable, Sendable {
    let catalogItemId: UUID
    let name: String
    let defaultCategory: String
    let defaultUnit: UnitType
    let searchKeywords: String?
    let createdAt: Date

    var id: UUID { catalogItemId }

    enum CodingKeys: String, CodingKey {
        case catalogItemId = "catalog_item_id"
        case name
        case defaultCategory = "default_category"
        case defaultUnit = "default_unit"
        case searchKeywords = "search_keywords"
        case createdAt = "created_at"
    }
}
