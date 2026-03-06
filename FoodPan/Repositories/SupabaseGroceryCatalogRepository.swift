import Foundation
import Supabase

final class SupabaseGroceryCatalogRepository: GroceryCatalogRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func search(query: String, limit: Int) async throws -> [GroceryCatalogItem] {
        try await client.from("grocery_catalog")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
    }
}
