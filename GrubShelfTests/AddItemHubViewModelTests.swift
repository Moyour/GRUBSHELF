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
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.catalogSearchVM.results.isEmpty)
        #expect(viewModel.catalogSearchVM.searchText.isEmpty)
    }
}
