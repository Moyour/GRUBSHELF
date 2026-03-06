import Foundation
@testable import FoodPan

final class MockPantryRepository: PantryRepository, @unchecked Sendable {
    var items: [PantryItem] = []
    var shouldThrow = false

    func fetchAll(householdId: UUID) async throws -> [PantryItem] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return items.filter { $0.householdId == householdId }
    }

    func add(_ item: PantryItem) async throws -> PantryItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        items.append(item)
        return item
    }

    func update(_ item: PantryItem) async throws -> PantryItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
            items[index] = item
        }
        return item
    }

    func delete(itemId: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        items.removeAll { $0.itemId == itemId }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]> {
        AsyncStream { $0.finish() }
    }
}
