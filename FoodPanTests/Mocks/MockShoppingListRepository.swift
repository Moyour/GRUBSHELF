import Foundation
@testable import FoodPan

final class MockShoppingListRepository: ShoppingListRepository, @unchecked Sendable {
    var lists: [ShoppingList] = []
    var shouldThrow = false

    func fetchAll(householdId: UUID) async throws -> [ShoppingList] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return lists.filter { $0.householdId == householdId }
    }

    func add(_ list: ShoppingList) async throws -> ShoppingList {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        lists.append(list)
        return list
    }

    func update(_ list: ShoppingList) async throws -> ShoppingList {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        if let index = lists.firstIndex(where: { $0.listId == list.listId }) {
            lists[index] = list
        }
        return list
    }

    func delete(listId: UUID) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        lists.removeAll { $0.listId == listId }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingList]> {
        AsyncStream { $0.finish() }
    }
}
