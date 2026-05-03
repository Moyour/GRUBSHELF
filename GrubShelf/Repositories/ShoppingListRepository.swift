import Foundation

protocol ShoppingListRepository: Sendable {
    func fetchAll(householdId: UUID) async throws -> [ShoppingList]
    func add(_ list: ShoppingList) async throws -> ShoppingList
    func update(_ list: ShoppingList) async throws -> ShoppingList
    func delete(listId: UUID) async throws
    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingList]>
}
