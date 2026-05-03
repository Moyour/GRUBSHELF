import Foundation
import Supabase

final class SupabaseGroceryCatalogRepository: GroceryCatalogRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func search(query: String, limit: Int) async throws -> [GroceryCatalogItem] {
        let sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: " ")  // Avoid breaking PostgREST or() separator
        let pattern = "*\(sanitized)*"  // PostgREST accepts * as % alias for ilike
        return try await withRetry { [client] in
            try await client.from("grocery_catalog")
                .select()
                .or("name.ilike.\(pattern),search_keywords.ilike.\(pattern)")
                .limit(limit)
                .execute()
                .value
        }
    }
}
