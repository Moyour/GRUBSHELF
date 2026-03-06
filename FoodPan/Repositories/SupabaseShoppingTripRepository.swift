import Foundation
import os
import Supabase

final class SupabaseShoppingTripRepository: ShoppingTripRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func add(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        try await client.from("shopping_trips")
            .insert(trip)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        try await client.from("shopping_trips")
            .update(trip)
            .eq("trip_id", value: trip.tripId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [ShoppingTrip] {
        try await client.from("shopping_trips")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("period", value: period)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [ShoppingTrip] {
        let startStr = ISO8601DateFormatter().string(from: start)
        let endStr = ISO8601DateFormatter().string(from: end)
        return try await client.from("shopping_trips")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .gte("date", value: startStr)
            .lte("date", value: endStr)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func fetchUnlogged(householdId: UUID) async throws -> [ShoppingTrip] {
        try await client.from("shopping_trips")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("cost_logged", value: false)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingTrip]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("shopping_trips_\(householdId.uuidString)")

            let task = Task {
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "shopping_trips",
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
                            let trips: [ShoppingTrip] = try await self.client.from("shopping_trips")
                                .select()
                                .eq("household_id", value: householdId.uuidString)
                                .order("date", ascending: false)
                                .execute()
                                .value
                            continuation.yield(trips)
                        } catch {
                            Logger(subsystem: "com.foodpan", category: "ShoppingTrips")
                                .error("Failed to fetch trips: \(error.localizedDescription)")
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
