import Foundation
import Supabase

final class SupabaseTransactionRepository: TransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func add(_ transaction: Transaction) async throws -> Transaction {
        try await withRetry { [client] in
            try await client.from("transactions")
                .insert(transaction)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [Transaction] {
        return try await withRetry { [client] in
            let formatter = ISO8601DateFormatter()
            return try await client.from("transactions")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .gte("purchase_date", value: formatter.string(from: start))
                .lte("purchase_date", value: formatter.string(from: end))
                .execute()
                .value
        }
    }
}
