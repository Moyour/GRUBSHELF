import Foundation
import Observation

@MainActor
@Observable
final class AddItemHubViewModel {
    var searchText = ""

    func triggerSearch() {
        catalogSearchVM.searchText = searchText
        catalogSearchVM.performSearch()
    }

    /// While set, the matching catalog row shows a spinner on its add control.
    var quickAddingCatalogItemId: UUID?

    var showAddForm = false
    var prefillItem: PantryItem?
    var prefillCatalogItem: GroceryCatalogItem?

    let catalogSearchVM: GroceryCatalogSearchViewModel

    private let pantryItems: [PantryItem]
    private let pantryRepository: PantryRepository

    var recentItems: [PantryItem] {
        var seen = Set<String>()
        return pantryItems
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.name.lowercased()).inserted }
            .prefix(10)
            .map { $0 }
    }

    init(
        pantryItems: [PantryItem],
        catalogRepository: GroceryCatalogRepository = SupabaseGroceryCatalogRepository(),
        pantryRepository: PantryRepository = SupabasePantryRepository()
    ) {
        self.pantryItems = pantryItems
        self.pantryRepository = pantryRepository
        self.catalogSearchVM = GroceryCatalogSearchViewModel(repository: catalogRepository)
    }

    /// Adds one unit using catalog defaults (same defaults as opening the add form from that row).
    func quickAddFromCatalog(
        _ catalogItem: GroceryCatalogItem,
        householdId: UUID,
        userId: UUID
    ) async {
        quickAddingCatalogItemId = catalogItem.id
        defer { quickAddingCatalogItemId = nil }

        let editor = AddEditPantryItemViewModel(
            repository: pantryRepository,
            householdId: householdId,
            userId: userId,
            catalogItem: catalogItem
        )
        let success = await editor.save()
        if success {
            searchText = ""
            catalogSearchVM.clear()
        }
    }
}
