import Foundation
import os
import Supabase

final class SupabaseWasteEventRepository: WasteEventRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func add(_ event: WasteEvent) async throws -> WasteEvent {
        try await client.from("waste_events")
            .insert(event)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [WasteEvent] {
        try await client.from("waste_events")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("period", value: period)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [WasteEvent] {
        let startStr = ISO8601DateFormatter().string(from: start)
        let endStr = ISO8601DateFormatter().string(from: end)
        return try await client.from("waste_events")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .gte("date", value: startStr)
            .lte("date", value: endStr)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[WasteEvent]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("waste_events_\(householdId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "waste_events",
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
                            let events: [WasteEvent] = try await self.client.from("waste_events")
                                .select()
                                .eq("household_id", value: householdId.uuidString)
                                .order("date", ascending: false)
                                .execute()
                                .value
                            continuation.yield(events)
                        } catch {
                            Logger(subsystem: "com.foodpan", category: "WasteEvents")
                                .error("Failed to fetch waste events: \(error.localizedDescription)")
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
