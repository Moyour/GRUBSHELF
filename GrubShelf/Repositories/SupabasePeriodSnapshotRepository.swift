import Foundation
import Supabase

final class SupabasePeriodSnapshotRepository: PeriodSnapshotRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func upsert(_ snapshot: PeriodSnapshot) async throws -> PeriodSnapshot {
        try await withRetry { [client] in
            try await client.from("period_snapshots")
                .upsert(snapshot)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func fetchRecent(householdId: UUID, limit: Int) async throws -> [PeriodSnapshot] {
        try await withRetry { [client] in
            try await client.from("period_snapshots")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .order("period", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
    }

    func fetch(householdId: UUID, period: String) async throws -> PeriodSnapshot? {
        let results: [PeriodSnapshot] = try await withRetry { [client] in
            try await client.from("period_snapshots")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .eq("period", value: period)
                .limit(1)
                .execute()
                .value
        }
        return results.first
    }
}
