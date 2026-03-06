import Testing
import Foundation
@testable import FoodPan

@MainActor
struct GroceryCatalogSearchViewModelTests {
    private func makeCatalogItem(name: String, category: String = "Fruits") -> GroceryCatalogItem {
        GroceryCatalogItem(
            catalogItemId: UUID(),
            name: name,
            defaultCategory: category,
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )
    }

    @Test func searchReturnsResults() async throws {
        let repo = MockGroceryCatalogRepository()
        repo.items = [
            makeCatalogItem(name: "Apple"),
            makeCatalogItem(name: "Apricot"),
            makeCatalogItem(name: "Banana"),
        ]
        let vm = GroceryCatalogSearchViewModel(repository: repo)
        vm.searchText = "Ap"
        vm.performSearch()

        // Wait for debounce (300ms) + search execution
        try await Task.sleep(for: .seconds(1))

        #expect(vm.results.count == 2)
        #expect(vm.results.allSatisfy { $0.name.contains("Ap") })
    }

    @Test func searchIgnoresShortQuery() async throws {
        let repo = MockGroceryCatalogRepository()
        repo.items = [makeCatalogItem(name: "Apple")]
        let vm = GroceryCatalogSearchViewModel(repository: repo)
        vm.searchText = "A"
        vm.performSearch()

        try await Task.sleep(for: .milliseconds(500))

        #expect(vm.results.isEmpty)
    }

    @Test func clearResetsState() async {
        let repo = MockGroceryCatalogRepository()
        let vm = GroceryCatalogSearchViewModel(repository: repo)
        vm.searchText = "Apple"
        vm.clear()
        #expect(vm.searchText.isEmpty)
        #expect(vm.results.isEmpty)
        #expect(vm.isSearching == false)
    }
}
