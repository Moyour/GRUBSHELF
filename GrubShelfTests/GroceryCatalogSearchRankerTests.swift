import Testing
import Foundation
@testable import GrubShelf

struct GroceryCatalogSearchRankerTests {
    private func catalogItem(name: String, category: String = "Beverages") -> GroceryCatalogItem {
        GroceryCatalogItem(
            catalogItemId: UUID(),
            name: name,
            defaultCategory: category,
            defaultUnit: .l,
            searchKeywords: nil,
            createdAt: .now
        )
    }

    private func waterRelatedItems() -> [GroceryCatalogItem] {
        [
            catalogItem(name: "Watermelon", category: "Fruits"),
            catalogItem(name: "Water", category: "Beverages"),
            catalogItem(name: "Sparkling Water", category: "Beverages"),
            catalogItem(name: "Coconut Water", category: "Beverages"),
            catalogItem(name: "Tonic Water", category: "Beverages"),
            catalogItem(name: "Water Chestnut", category: "Vegetables"),
            catalogItem(name: "Watercress", category: "Vegetables"),
            catalogItem(name: "Waterleaf", category: "Vegetables"),
        ]
    }

    @Test func appleQueryHidesPineappleAndPrefersExactApple() {
        let items = [
            catalogItem(name: "Pineapple", category: "Fruits"),
            catalogItem(name: "Apple", category: "Fruits"),
            catalogItem(name: "Apple Juice", category: "Beverages"),
        ]

        let suggestions = GroceryCatalogSearchRanker.suggestions(from: items, query: "apple")

        #expect(suggestions.first?.name == "Apple")
        #expect(!suggestions.contains(where: { $0.name == "Pineapple" }))
        #expect(suggestions.contains(where: { $0.name == "Apple Juice" }))
    }

    @Test func pineappleQueryShowsPineapple() {
        let items = [
            catalogItem(name: "Pineapple", category: "Fruits"),
            catalogItem(name: "Apple", category: "Fruits"),
        ]

        let suggestions = GroceryCatalogSearchRanker.suggestions(from: items, query: "pineapple")

        #expect(suggestions.first?.name == "Pineapple")
    }

    @Test func blackQueryHidesBlackberryButShowsBlackTea() {
        let items = [
            catalogItem(name: "Blackberry", category: "Fruits"),
            catalogItem(name: "Black Tea", category: "Beverages"),
        ]

        let suggestions = GroceryCatalogSearchRanker.suggestions(from: items, query: "black")

        #expect(!suggestions.contains(where: { $0.name == "Blackberry" }))
        #expect(suggestions.contains(where: { $0.name == "Black Tea" }))
    }

    @Test func waterQueryHidesCompoundWordsAndPrefersBeverages() {
        let suggestions = GroceryCatalogSearchRanker.suggestions(from: waterRelatedItems(), query: "water")

        #expect(suggestions.first?.name == "Water")
        #expect(!suggestions.contains(where: { $0.name == "Watermelon" }))
        #expect(!suggestions.contains(where: { $0.name == "Watercress" }))
        #expect(!suggestions.contains(where: { $0.name == "Waterleaf" }))
        #expect(suggestions.contains(where: { $0.name == "Sparkling Water" }))
        #expect(suggestions.contains(where: { $0.name == "Coconut Water" }))
        #expect(suggestions.contains(where: { $0.name == "Water Chestnut" }))
    }

    @Test func waterQueryStillFindsWatermelonWhenTypedFurther() {
        let items = waterRelatedItems()
        let suggestions = GroceryCatalogSearchRanker.suggestions(from: items, query: "watermel")

        #expect(suggestions.contains(where: { $0.name == "Watermelon" }))
    }

    @Test func coconutWaterExactMatch() {
        let items = waterRelatedItems()
        let match = GroceryCatalogSearchRanker.exactMatch(in: items, query: "Coconut Water")

        #expect(match?.name == "Coconut Water")
    }

    @Test func shoppingNamesMatchRequiresExactEquality() {
        #expect(GroceryCatalogSearchRanker.shoppingNamesMatch("Water", "water"))
        #expect(GroceryCatalogSearchRanker.shoppingNamesMatch("Coconut Water", "coconut water"))
        #expect(!GroceryCatalogSearchRanker.shoppingNamesMatch("Water", "Watermelon"))
        #expect(!GroceryCatalogSearchRanker.shoppingNamesMatch("Sparkling Water", "Watermelon"))
        #expect(!GroceryCatalogSearchRanker.shoppingNamesMatch("Water", "Watercress"))
    }

    @Test func matchesCatalogPrefersIdOverName() {
        let blackberryCatalog = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Blackberry",
            defaultCategory: "Fruits",
            defaultUnit: .g,
            searchKeywords: nil,
            createdAt: .now
        )
        let blackTeaCatalog = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Black Tea",
            defaultCategory: "Beverages",
            defaultUnit: .g,
            searchKeywords: nil,
            createdAt: .now
        )

        let blackberryOnList = ShoppingItem(
            itemId: UUID(),
            householdId: UUID(),
            listId: nil,
            name: "Blackberry",
            quantity: 1,
            unit: .g,
            category: "Fruits",
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            catalogItemId: blackberryCatalog.catalogItemId
        )

        #expect(GroceryCatalogSearchRanker.matchesCatalog(blackberryOnList, catalog: blackberryCatalog))
        #expect(!GroceryCatalogSearchRanker.matchesCatalog(blackberryOnList, catalog: blackTeaCatalog))
    }

    @Test func shouldCombineShoppingQuantityRequiresMatchingCatalogId() {
        let wholeMilk = catalogItem(name: "Whole Milk", category: "Dairy")
        let chocolateMilk = catalogItem(name: "Chocolate Milk", category: "Dairy")
        let onList = ShoppingItem(
            itemId: UUID(),
            householdId: UUID(),
            listId: UUID(),
            name: wholeMilk.name,
            quantity: 1,
            unit: .l,
            category: "Dairy",
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            catalogItemId: wholeMilk.catalogItemId
        )

        #expect(GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(existing: onList, catalog: wholeMilk))
        #expect(!GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(existing: onList, catalog: chocolateMilk))
        #expect(
            !GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(
                existing: onList,
                newName: "Chocolate Milk",
                newCatalogId: chocolateMilk.catalogItemId
            )
        )
    }

    @Test func shouldCombineShoppingQuantityMergesSameFreeTextName() {
        let bananas = ShoppingItem(
            itemId: UUID(),
            householdId: UUID(),
            listId: UUID(),
            name: "Bananas",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            catalogItemId: nil
        )
        #expect(
            GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(
                existing: bananas,
                newName: "Bananas",
                newCatalogId: nil
            )
        )
        #expect(
            !GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(
                existing: bananas,
                newName: "Apples",
                newCatalogId: nil
            )
        )
    }

    @Test func distinctCatalogProductsNeverCombine() {
        let apple = catalogItem(name: "Apple", category: "Fruits")
        let pineapple = catalogItem(name: "Pineapple", category: "Fruits")
        let appleOnList = ShoppingItem(
            itemId: UUID(),
            householdId: UUID(),
            listId: UUID(),
            name: apple.name,
            quantity: 1,
            unit: .pcs,
            category: "Fruits",
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            catalogItemId: apple.catalogItemId
        )
        #expect(!GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(existing: appleOnList, catalog: pineapple))
    }

    @Test func matchesCatalogRequiresStoredCatalogId() {
        let waterCatalog = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Water",
            defaultCategory: "Beverages",
            defaultUnit: .l,
            searchKeywords: nil,
            createdAt: .now
        )
        let legacyWatermelonOnList = ShoppingItem(
            itemId: UUID(),
            householdId: UUID(),
            listId: nil,
            name: "Watermelon",
            quantity: 1,
            unit: .pcs,
            category: "Fruits",
            completed: false,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            catalogItemId: nil
        )

        #expect(!GroceryCatalogSearchRanker.matchesCatalog(legacyWatermelonOnList, catalog: waterCatalog))
    }

    @Test func substringQueryShowsWordBoundaryHitsNotEmbeddedTraps() {
        let items = [
            catalogItem(name: "Ham", category: "Meat"),
            catalogItem(name: "Deli Ham", category: "Meat"),
            catalogItem(name: "Hamburger Buns", category: "Grains"),
            catalogItem(name: "Graham Crackers", category: "Snacks"),
        ]
        let suggestions = GroceryCatalogSearchRanker.suggestions(from: items, query: "ham", limit: 8)
        #expect(suggestions.contains(where: { $0.name == "Ham" }))
        #expect(suggestions.contains(where: { $0.name == "Deli Ham" }))
        #expect(!suggestions.contains(where: { $0.name == "Hamburger Buns" }))
        #expect(!suggestions.contains(where: { $0.name == "Graham Crackers" }))
    }
}

struct ItemIconMapperWaterTests {
    @Test func waterKeywordDoesNotMatchWatermelon() {
        #expect(ItemIconMapper.emoji(for: "Watermelon", category: "Fruits") == "🍉")
    }

    @Test func waterKeywordMatchesSparklingWater() {
        #expect(ItemIconMapper.emoji(for: "Sparkling Water", category: "Beverages") == "💧")
    }
}
