import Foundation
@testable import GrubShelf

final class MockPantryRepository: PantryRepository, @unchecked Sendable {
    var items: [PantryItem] = []
    var shouldThrow = false
    /// Optional suspension before returning, enabling in-flight concurrency tests.
    var operationDelay: Duration?

    private(set) var addCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0

    private func applySuspension() async throws {
        if let d = operationDelay { try await Task.sleep(for: d) }
    }

    func fetchAll(householdId: UUID) async throws -> [PantryItem] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return items.filter { $0.householdId == householdId }
    }

    func add(_ item: PantryItem) async throws -> PantryItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        addCallCount += 1
        items.append(item)
        return item
    }

    func update(_ item: PantryItem) async throws -> PantryItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        updateCallCount += 1
        if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
            items[index] = item
        }
        return item
    }

    func delete(itemId: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        deleteCallCount += 1
        items.removeAll { $0.itemId == itemId }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]> {
        AsyncStream { $0.finish() }
    }
}
