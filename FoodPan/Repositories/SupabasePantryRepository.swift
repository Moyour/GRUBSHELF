import Foundation
import os
import Supabase

final class SupabasePantryRepository: PantryRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchAll(householdId: UUID) async throws -> [PantryItem] {
        try await client.from("pantry_items")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("archived", value: false)
            .execute()
            .value
    }

    func add(_ item: PantryItem) async throws -> PantryItem {
        try await client.from("pantry_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ item: PantryItem) async throws -> PantryItem {
        try await client.from("pantry_items")
            .update(item)
            .eq("item_id", value: item.itemId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(itemId: UUID) async throws {
        try await client.from("pantry_items")
            .delete()
            .eq("item_id", value: itemId.uuidString)
            .execute()
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("pantry_\(householdId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "pantry_items",
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
                            Logger(subsystem: "com.foodpan", category: "Pantry")
                                .error("Failed to fetch pantry items: \(error.localizedDescription)")
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
