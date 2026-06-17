import Foundation
import os
import Supabase

final class SupabaseWasteEventRepository: WasteEventRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func add(_ event: WasteEvent) async throws -> WasteEvent {
        try await withRetry { [client] in
            try await client.from("waste_events")
                .insert(event)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [WasteEvent] {
        try await withRetry { [client] in
            try await client.from("waste_events")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .eq("period", value: period)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [WasteEvent] {
        let startStr = ISO8601DateFormatter.shared.string(from: start)
        let endStr = ISO8601DateFormatter.shared.string(from: end)
        return try await withRetry { [client] in
            try await client.from("waste_events")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .gte("date", value: startStr)
                .lte("date", value: endStr)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[WasteEvent]> {
        observeWithDebounce(
            client: client,
            channelName: "waste_events_\(householdId.uuidString)",
            table: "waste_events",
            filterColumn: "household_id",
            filterValue: householdId,
            logCategory: "WasteEvents"
        ) { [self] in
            try await client.from("waste_events")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value
        }
    }
}
