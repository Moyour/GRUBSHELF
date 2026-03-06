import Foundation

protocol PantryRepository: Sendable {
    func fetchAll(householdId: UUID) async throws -> [PantryItem]
    func add(_ item: PantryItem) async throws -> PantryItem
    func update(_ item: PantryItem) async throws -> PantryItem
    func delete(itemId: UUID) async throws
    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]>
}
