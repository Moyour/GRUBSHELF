import Foundation
import Supabase

final class SupabaseFinanceSettingsRepository: FinanceSettingsRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetch(userId: UUID) async throws -> FinanceSettings? {
        let results: [FinanceSettings] = try await withRetry { [client] in
            try await client.from("finance_settings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
        }
        return results.first
    }

    func upsert(_ settings: FinanceSettings) async throws -> FinanceSettings {
        try await withRetry { [client] in
            try await client.from("finance_settings")
                .upsert(settings)
                .select()
                .single()
                .execute()
                .value
        }
    }
}
