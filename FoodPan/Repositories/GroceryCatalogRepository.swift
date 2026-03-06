import Foundation

protocol GroceryCatalogRepository: Sendable {
    func search(query: String, limit: Int) async throws -> [GroceryCatalogItem]
}
