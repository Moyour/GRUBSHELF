import Foundation
import os
import Supabase

    /// Insert-only payload that omits `transferred` (uses DB default).
    private struct ShoppingListInsert: Encodable {
        let listId: UUID
        let householdId: UUID
        let name: String
        let createdBy: UUID
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case listId = "list_id"
            case householdId = "household_id"
            case name
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Update-only payload that omits immutable fields.
    private struct ShoppingListUpdate: Encodable {
        let name: String
        let updatedAt: Date
        let transferred: Bool

        enum CodingKeys: String, CodingKey {
            case name
            case updatedAt = "updated_at"
            case transferred
        }
    }

final class SupabaseShoppingListRepository: ShoppingListRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchAll(householdId: UUID) async throws -> [ShoppingList] {
        try await client.from("shopping_lists")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func add(_ list: ShoppingList) async throws -> ShoppingList {
        let insert = ShoppingListInsert(
            listId: list.listId,
            householdId: list.householdId,
            name: list.name,
            createdBy: list.createdBy,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt
        )
        return try await client.from("shopping_lists")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ list: ShoppingList) async throws -> ShoppingList {
        let payload = ShoppingListUpdate(
            name: list.name,
            updatedAt: list.updatedAt,
            transferred: list.transferred
        )
        return try await client.from("shopping_lists")
            .update(payload)
            .eq("list_id", value: list.listId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(listId: UUID) async throws {
        try await client.from("shopping_lists")
            .delete()
            .eq("list_id", value: listId.uuidString)
            .execute()
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingList]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("shopping_lists_\(householdId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "shopping_lists",
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
                            let lists = try await self.fetchAll(householdId: householdId)
                            continuation.yield(lists)
                        } catch {
                            Logger(subsystem: "com.foodpan", category: "ShoppingLists")
                                .error("Failed to fetch shopping lists: \(error.localizedDescription)")
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
