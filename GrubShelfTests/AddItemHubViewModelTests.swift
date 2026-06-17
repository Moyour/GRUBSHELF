import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct AddItemHubViewModelTests {
    @Test func quickAddFromCatalogAddsItemToPantry() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Cherry",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let catalogRepo = MockGroceryCatalogRepository()
        catalogRepo.items = [catalogItem]
        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: catalogRepo,
            pantryRepository: pantryRepo
        )
        viewModel.searchText = "cher"
        viewModel.catalogSearchVM.searchText = "cher"
        viewModel.catalogSearchVM.results = [catalogItem]

        await viewModel.quickAddFromCatalog(
            catalogItem,
            householdId: householdId,
            userId: userId
        )

        #expect(pantryRepo.items.count == 1)
        #expect(pantryRepo.items.first?.householdId == householdId)
        #expect(pantryRepo.items.first?.createdBy == userId)
        #expect(pantryRepo.items.first?.name == "Cherry")
        #expect(pantryRepo.items.first?.quantity == 1)
        #expect(pantryRepo.items.first?.unit == .pcs)
        #expect(pantryRepo.items.first?.category == "Fruits")
        // Multi-add: search state is preserved (not cleared)
        #expect(viewModel.searchText == "cher")
        #expect(!viewModel.catalogSearchVM.results.isEmpty)
        #expect(viewModel.catalogSearchVM.searchText == "cher")
    }

    @Test func quickAddFromCatalogTracksAddedCount() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let cherry = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Cherry",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )
        let banana = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Banana",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        #expect(viewModel.addedCount == 0)
        #expect(!viewModel.alreadyAdded("Cherry"))

        await viewModel.quickAddFromCatalog(cherry, householdId: householdId, userId: userId)
        #expect(viewModel.addedCount == 1)
        #expect(viewModel.alreadyAdded("Cherry"))

        await viewModel.quickAddFromCatalog(banana, householdId: householdId, userId: userId)
        #expect(viewModel.addedCount == 2)
        #expect(viewModel.alreadyAdded("Banana"))
    }

    @Test func quickAddRecentTracksAddedCount() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()

        let recentItem = PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: "Milk",
            quantity: 1,
            unit: .pcs,
            category: "Dairy",
            storageLocation: .fridge,
            expiryDate: nil,
            costPerUnitMinor: nil,
            lowStockThreshold: 1,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            archived: false,
            lastQuantityUpdateDate: .now,
            expectedUsageCycleDays: 7,
            photoPath: nil,
            approvalStatus: .approved
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [recentItem],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        #expect(viewModel.addedCount == 0)

        await viewModel.quickAddRecent(recentItem, householdId: householdId, userId: userId)
        #expect(viewModel.addedCount == 1)
        #expect(viewModel.alreadyAdded("Milk"))
    }

    @Test func alreadyAddedIsCaseInsensitive() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Cherry",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        await viewModel.quickAddFromCatalog(catalogItem, householdId: householdId, userId: userId)

        #expect(viewModel.alreadyAdded("cherry"))
        #expect(viewModel.alreadyAdded("CHERRY"))
        #expect(viewModel.alreadyAdded("Cherry"))
        #expect(!viewModel.alreadyAdded("Banana"))
    }

    // MARK: - AddedPantryEntry tracking

    @Test func addedItemsTracksFullEntryData() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Apple",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        await viewModel.quickAddFromCatalog(catalogItem, householdId: householdId, userId: userId)

        #expect(viewModel.addedItems.count == 1)
        let entry = viewModel.addedItems[0]
        #expect(entry.name == "Apple")
        #expect(entry.unit == .pcs)
        #expect(entry.category == "Fruits")
        #expect(entry.quantity == 1)
    }

    @Test func removeItemDeletesFromRepoAndTracking() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Bread",
            defaultCategory: "Grains",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        await viewModel.quickAddFromCatalog(catalogItem, householdId: householdId, userId: userId)
        #expect(viewModel.addedCount == 1)
        #expect(viewModel.alreadyAdded("Bread"))

        let itemId = viewModel.addedItems[0].id
        viewModel.removeItem(itemId: itemId)

        #expect(viewModel.addedCount == 0)
        #expect(!viewModel.alreadyAdded("Bread"))
    }

    @Test func updateQuantityPersistsToRepo() async {
        let householdId = UUID()
        let userId = UUID()
        let pantryRepo = MockPantryRepository()
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Eggs",
            defaultCategory: "Dairy",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )

        let viewModel = AddItemHubViewModel(
            pantryItems: [],
            catalogRepository: MockGroceryCatalogRepository(),
            pantryRepository: pantryRepo
        )

        await viewModel.quickAddFromCatalog(catalogItem, householdId: householdId, userId: userId)
        let itemId = viewModel.addedItems[0].id

        viewModel.updateQuantity(itemId: itemId, newQuantity: 5)

        #expect(viewModel.addedItems[0].quantity == 5)
    }
}
