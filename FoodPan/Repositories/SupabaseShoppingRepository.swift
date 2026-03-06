import Foundation
import os
import Supabase

    /// Insert-only payload that omits `transferred` (uses DB default).
    private struct ShoppingItemInsert: Encodable {
        let itemId: UUID
        let householdId: UUID
        let listId: UUID?
        let name: String
        let quantity: Double
        let unit: UnitType?
        let category: String?
        let completed: Bool
        let createdBy: UUID
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case itemId = "item_id"
            case householdId = "household_id"
            case listId = "list_id"
            case name, quantity, unit, category, completed
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Update-only payload — omits immutable fields and `transferred`.
    private struct ShoppingItemUpdate: Encodable {
        let name: String
        let quantity: Double
        let unit: UnitType?
        let category: String?
        let completed: Bool
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case name, quantity, unit, category, completed
            case updatedAt = "updated_at"
        }
    }

    /// Transfer-specific payload — only sets transferred flag.
    private struct ShoppingItemTransferUpdate: Encodable {
        let transferred: Bool
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case transferred
            case updatedAt = "updated_at"
        }
    }

final class SupabaseShoppingRepository: ShoppingRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchAll(householdId: UUID) async throws -> [ShoppingItem] {
        try await client.from("shopping_items")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .execute()
            .value
    }

    func fetchByList(listId: UUID) async throws -> [ShoppingItem] {
        try await client.from("shopping_items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .execute()
            .value
    }

    func add(_ item: ShoppingItem) async throws -> ShoppingItem {
        let insert = ShoppingItemInsert(
            itemId: item.itemId,
            householdId: item.householdId,
            listId: item.listId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            completed: item.completed,
            createdBy: item.createdBy,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        return try await client.from("shopping_items")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ item: ShoppingItem) async throws -> ShoppingItem {
        let payload = ShoppingItemUpdate(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            completed: item.completed,
            updatedAt: item.updatedAt
        )
        return try await client.from("shopping_items")
            .update(payload)
            .eq("item_id", value: item.itemId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func markTransferred(itemId: UUID) async throws -> ShoppingItem {
        let payload = ShoppingItemTransferUpdate(
            transferred: true,
            updatedAt: .now
        )
        return try await client.from("shopping_items")
            .update(payload)
            .eq("item_id", value: itemId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(itemId: UUID) async throws {
        try await client.from("shopping_items")
            .delete()
            .eq("item_id", value: itemId.uuidString)
            .execute()
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingItem]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("shopping_\(householdId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "shopping_items",
                    filter: .eq("household_id", value: householdId)
                )

                try? await channel.subscribeWithError()

                var debounceTask: Task<Void, Never>?
                for await _ in changes {
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        do {
                            let items = try await self.fetchAll(householdId: householdId)
                            continuation.yield(items)
                        } catch {
                            Logger(subsystem: "com.foodpan", category: "ShoppingItems")
                                .error("Failed to fetch shopping items: \(error.localizedDescription)")
                        }
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }

    func observeListChanges(listId: UUID) -> AsyncStream<[ShoppingItem]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("shopping_list_\(listId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "shopping_items",
                    filter: .eq("list_id", value: listId)
                )

                try? await channel.subscribeWithError()

                var debounceTask: Task<Void, Never>?
                for await _ in changes {
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        do {
                            let items = try await self.fetchByList(listId: listId)
                            continuation.yield(items)
                        } catch {
                            Logger(subsystem: "com.foodpan", category: "ShoppingItems")
                                .error("Failed to fetch shopping items: \(error.localizedDescription)")
                        }
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }
}
