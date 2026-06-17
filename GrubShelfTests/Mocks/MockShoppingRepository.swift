import Foundation
@testable import GrubShelf

final class MockShoppingRepository: ShoppingRepository, @unchecked Sendable {
    var items: [ShoppingItem] = []
    var shouldThrow = false
    /// Optional suspension before returning, enabling in-flight concurrency tests.
    var operationDelay: Duration?

    private(set) var addCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0

    private func applySuspension() async throws {
        if let d = operationDelay { try await Task.sleep(for: d) }
    }

    func fetchAll(householdId: UUID) async throws -> [ShoppingItem] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return items.filter { $0.householdId == householdId }
    }

    func fetchByList(listId: UUID) async throws -> [ShoppingItem] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return items.filter { $0.listId == listId }
    }

    func add(_ item: ShoppingItem) async throws -> ShoppingItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        addCallCount += 1
        items.append(item)
        return item
    }

    func update(_ item: ShoppingItem) async throws -> ShoppingItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        updateCallCount += 1
        if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
            items[index] = item
        }
        return item
    }

    func markTransferred(itemId: UUID) async throws -> ShoppingItem {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let index = items.firstIndex(where: { $0.itemId == itemId }) {
            items[index].transferred = true
            items[index].updatedAt = .now
            return items[index]
        }
        throw NSError(domain: "test", code: 404)
    }

    func delete(itemId: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        try await applySuspension()
        deleteCallCount += 1
        items.removeAll { $0.itemId == itemId }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingItem]> {
        AsyncStream { $0.finish() }
    }

    func observeListChanges(listId: UUID) -> AsyncStream<[ShoppingItem]> {
        AsyncStream { $0.finish() }
    }
}
