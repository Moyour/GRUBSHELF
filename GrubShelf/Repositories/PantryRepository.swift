import Foundation

protocol PantryRepository: Sendable {
    func fetchAll(householdId: UUID) async throws -> [PantryItem]
    func add(_ item: PantryItem) async throws -> PantryItem
    func update(_ item: PantryItem) async throws -> PantryItem
    func delete(itemId: UUID) async throws
    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]>
}

// MARK: - Household barcode labels (saved name per scan)

struct HouseholdBarcodeLabel: Codable, Equatable, Sendable {
    let householdId: UUID
    let barcode: String
    let displayName: String
    let category: String
    let catalogItemId: UUID?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case barcode
        case displayName = "display_name"
        case category
        case catalogItemId = "catalog_item_id"
        case updatedAt = "updated_at"
    }
}

protocol BarcodeLabelRepository: Sendable {
    func fetchLabel(householdId: UUID, barcode: String) async throws -> HouseholdBarcodeLabel?
    func upsertLabel(
        householdId: UUID,
        barcode: String,
        displayName: String,
        category: String,
        catalogItemId: UUID?
    ) async throws
}
