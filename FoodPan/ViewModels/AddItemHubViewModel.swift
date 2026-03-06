import Foundation
import Observation

@MainActor
@Observable
final class AddItemHubViewModel {
    var searchText: String = ""

    func triggerSearch() {
        catalogSearchVM.searchText = searchText
        catalogSearchVM.performSearch()
    }
    var showAddForm = false
    var showBarcodeScanner = false
    var isLookingUpBarcode = false
    var prefillItem: PantryItem?
    var prefillCatalogItem: GroceryCatalogItem?
    var barcodeName: String?
    var barcodeCategory: String?

    let catalogSearchVM: GroceryCatalogSearchViewModel

    private let pantryItems: [PantryItem]

    var recentItems: [PantryItem] {
        var seen = Set<String>()
        return pantryItems
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.name.lowercased()).inserted }
            .prefix(10)
            .map { $0 }
    }

    init(pantryItems: [PantryItem], catalogRepository: GroceryCatalogRepository) {
        self.pantryItems = pantryItems
        self.catalogSearchVM = GroceryCatalogSearchViewModel(repository: catalogRepository)
    }

    func handleBarcode(_ code: String) async {
        isLookingUpBarcode = true
        defer { isLookingUpBarcode = false }

        showBarcodeScanner = false

        do {
            guard let product = try await OpenFoodFactsService.lookup(barcode: code) else {
                ToastManager.shared.show("Product not found for this barcode", style: .error)
                return
            }
            barcodeName = product.name
            barcodeCategory = product.category
            prefillItem = nil
            prefillCatalogItem = nil
            showAddForm = true
        } catch let error as BarcodeError {
            ToastManager.shared.show(error.localizedDescription, style: .error)
        } catch {
            ToastManager.shared.show("Could not look up barcode — try again", style: .error)
        }
    }
}
