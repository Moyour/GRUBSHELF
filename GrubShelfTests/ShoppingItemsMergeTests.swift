import Testing
import Foundation
@testable import GrubShelf

struct ShoppingItemsMergeTests {
    private func item(id: UUID, name: String) -> ShoppingItem {
        ShoppingItem(
            itemId: id,
            householdId: UUID(),
            listId: UUID(),
            name: name,
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func mergingPreservesLocalRowsNotYetOnServer() {
        let localA = item(id: UUID(), name: "Ham")
        let localB = item(id: UUID(), name: "Deli Ham")
        let serverOnlyA = item(id: localA.itemId, name: "Ham")

        let merged = ShoppingItemsMerge.merging(server: [serverOnlyA], preservingLocal: [localA, localB])

        #expect(merged.count == 2)
        #expect(merged.contains(where: { $0.itemId == localA.itemId }))
        #expect(merged.contains(where: { $0.itemId == localB.itemId }))
    }
}

struct GroceryCatalogUniqueByIdTests {
    @Test func uniqueByCatalogIdKeepsDistinctProducts() {
        let id1 = UUID()
        let id2 = UUID()
        let items = [
            GroceryCatalogItem(
                catalogItemId: id1,
                name: "Ham",
                defaultCategory: "Meat",
                defaultUnit: .g,
                searchKeywords: nil,
                createdAt: .now
            ),
            GroceryCatalogItem(
                catalogItemId: id1,
                name: "Ham Duplicate",
                defaultCategory: "Meat",
                defaultUnit: .g,
                searchKeywords: nil,
                createdAt: .now
            ),
            GroceryCatalogItem(
                catalogItemId: id2,
                name: "Deli Ham",
                defaultCategory: "Meat",
                defaultUnit: .g,
                searchKeywords: nil,
                createdAt: .now
            ),
        ]
        let unique = GroceryCatalogSearchRanker.uniqueByCatalogId(items)
        #expect(unique.count == 2)
        #expect(unique.contains(where: { $0.name == "Ham" }))
        #expect(unique.contains(where: { $0.name == "Deli Ham" }))
    }
}
