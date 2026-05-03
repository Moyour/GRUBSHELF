import Foundation
@testable import GrubShelf

final class MockGroceryCatalogRepository: GroceryCatalogRepository, @unchecked Sendable {
    var items: [GroceryCatalogItem] = []
    var shouldThrow = false

    func search(query: String, limit: Int) async throws -> [GroceryCatalogItem] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        let lowered = query.lowercased()
        return items.filter { $0.name.lowercased().contains(lowered) }
            .prefix(limit)
            .map { $0 }
    }
}
