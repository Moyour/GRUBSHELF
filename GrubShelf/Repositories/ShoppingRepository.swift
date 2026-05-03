import Foundation

protocol ShoppingRepository: Sendable {
    func fetchAll(householdId: UUID) async throws -> [ShoppingItem]
    func fetchByList(listId: UUID) async throws -> [ShoppingItem]
    func add(_ item: ShoppingItem) async throws -> ShoppingItem
    func update(_ item: ShoppingItem) async throws -> ShoppingItem
    func markTransferred(itemId: UUID) async throws -> ShoppingItem
    func delete(itemId: UUID) async throws
    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingItem]>
    func observeListChanges(listId: UUID) -> AsyncStream<[ShoppingItem]>
}
