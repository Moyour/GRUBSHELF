import Foundation
import os
import Supabase

final class SupabaseShoppingTripRepository: ShoppingTripRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func add(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        try await withRetry { [client] in
            try await client.from("shopping_trips")
                .insert(trip)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func update(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        try await withRetry { [client] in
            try await client.from("shopping_trips")
                .update(trip)
                .eq("trip_id", value: trip.tripId.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [ShoppingTrip] {
        try await withRetry { [client] in
            try await client.from("shopping_trips")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .eq("period", value: period)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [ShoppingTrip] {
        let startStr = ISO8601DateFormatter.shared.string(from: start)
        let endStr = ISO8601DateFormatter.shared.string(from: end)
        return try await withRetry { [client] in
            try await client.from("shopping_trips")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .gte("date", value: startStr)
                .lte("date", value: endStr)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }

    func fetchRecent(householdId: UUID, limit: Int) async throws -> [ShoppingTrip] {
        try await withRetry { [client] in
            try await client.from("shopping_trips")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .order("date", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
    }

    func fetchUnlogged(householdId: UUID) async throws -> [ShoppingTrip] {
        try await withRetry { [client] in
            try await client.from("shopping_trips")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .eq("cost_logged", value: false)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingTrip]> {
        observeWithDebounce(
            client: client,
            channelName: "shopping_trips_\(householdId.uuidString)",
            table: "shopping_trips",
            filterColumn: "household_id",
            filterValue: householdId,
            logCategory: "ShoppingTrips"
        ) { [self] in
            try await client.from("shopping_trips")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }
}
