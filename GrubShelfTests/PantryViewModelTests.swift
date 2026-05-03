import Testing
import Foundation
import UIKit
@testable import GrubShelf

@MainActor
struct PantryViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makeItem(
        name: String = "Milk",
        category: String = "Dairy",
        state: ItemState = .active,
        storageLocation: PantryStorageLocation = .fridge
    ) -> PantryItem {
        let expiry: Date? = switch state {
        case .expired: Date.now.addingTimeInterval(-86400)
        case .expiringSoon: Date.now.addingTimeInterval(86400)
        default: nil
        }
        return PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: name,
            quantity: state == .archived ? 0 : (state == .lowStock ? 1 : 10),
            unit: .l,
            category: category,
            storageLocation: storageLocation,
            expiryDate: expiry,
            costPerUnitMinor: nil,
            lowStockThreshold: state == .lowStock ? 1 : 0,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: state == .archived
        )
    }

    @Test func loadItemsPopulates() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk"),
            makeItem(name: "Eggs"),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        #expect(vm.items.count == 2)
    }

    @Test func filteredItemsShowsAll() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", state: .active),
            makeItem(name: "Old Bread", state: .expired),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedLocationFilter = .all
        vm.selectedAttention = .none
        #expect(vm.filteredItems.count == 2)
    }

    @Test func filteredItemsExpiringAttention() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", state: .active),
            makeItem(name: "Expiring Yogurt", state: .expiringSoon),
            makeItem(name: "Old Bread", state: .expired),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedLocationFilter = .all
        vm.selectedAttention = .expiring
        #expect(vm.filteredItems.count == 2)
    }

    @Test func filteredItemsLowStockAttention() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", state: .active),
            makeItem(name: "Salt", state: .lowStock),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedLocationFilter = .all
        vm.selectedAttention = .lowStock
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.name == "Salt")
    }

    @Test func filteredItemsFridgeLocation() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", category: "Dairy", storageLocation: .fridge),
            makeItem(name: "Pasta", category: "Grains", storageLocation: .shelf),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedLocationFilter = .fridge
        vm.selectedAttention = .none
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.name == "Milk")
    }

    @Test func applyNavigationFocusSetsFilters() async {
        let vm = PantryViewModel(repository: MockPantryRepository(), householdId: householdId, userId: userId)
        vm.applyNavigationFocus(.lowStock)
        #expect(vm.selectedLocationFilter == .all)
        #expect(vm.selectedAttention == .lowStock)
    }

    @Test func searchFiltersItems() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Whole Milk", category: "Dairy"),
            makeItem(name: "Almond Milk", category: "Dairy"),
            makeItem(name: "Eggs", category: "Protein"),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.searchText = "Milk"
        #expect(vm.filteredItems.count == 2)
    }

    @Test func searchByCategory() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Whole Milk", category: "Dairy"),
            makeItem(name: "Eggs", category: "Protein"),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.searchText = "Protein"
        #expect(vm.filteredItems.count == 1)
    }

    @Test func groupedFilteredByCategory() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", category: "Dairy"),
            makeItem(name: "Cheese", category: "Dairy"),
            makeItem(name: "Eggs", category: "Protein"),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        let grouped = vm.groupedFilteredByCategory
        #expect(grouped.count == 2)
    }

    @Test func homeExpiringPreviewItemsOrdersSoonestFirst() async {
        let repo = MockPantryRepository()
        repo.items = [
            PantryItem(
                itemId: UUID(),
                householdId: householdId,
                name: "Later",
                quantity: 10,
                unit: .l,
                category: "Other",
                storageLocation: .fridge,
                expiryDate: Date.now.addingTimeInterval(10 * 86400),
                costPerUnitMinor: nil,
                lowStockThreshold: 0,
                createdBy: userId,
                createdAt: .now,
                updatedAt: .now,
                archived: false
            ),
            makeItem(name: "Old Bread", state: .expired),
            makeItem(name: "Soon Yogurt", state: .expiringSoon),
        ]

        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()

        let preview = vm.homeExpiringPreviewItems
        #expect(preview.count == 2)
        #expect(preview.map(\.name) == ["Old Bread", "Soon Yogurt"])
    }

    @Test func homeExpiringPreviewItemsCapsAtFive() async {
        let repo = MockPantryRepository()
        repo.items = (0..<7).map { i in
            makeItem(name: "Expiring \(i)", state: .expiringSoon)
        }
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        #expect(vm.homeExpiringPreviewItems.count == 5)
    }

    @Test func homeExpiringPreviewItemsExcludesArchived() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Gone", state: .archived),
            makeItem(name: "Milk", state: .expiringSoon),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        #expect(vm.homeExpiringPreviewItems.count == 1)
        #expect(vm.homeExpiringPreviewItems.first?.name == "Milk")
    }

    @Test func deleteItemRemovesFromList() async {
        let repo = MockPantryRepository()
        let item = makeItem(name: "Milk")
        repo.items = [item]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        #expect(vm.items.count == 1)
        await vm.deleteItem(item)
        #expect(vm.items.isEmpty)
    }

    @Test func incrementItemPersistsQuantity() async {
        let repo = MockPantryRepository()
        let item = makeItem(name: "Milk")
        repo.items = [item]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        #expect(vm.items.first?.quantity == 10)
        await vm.incrementItem(item)
        #expect(vm.items.first?.quantity == 11)
    }

    @Test func confirmRemoveFromListDeletesWithoutWasteEvent() async {
        let repo = MockPantryRepository()
        let wasteRepo = MockWasteEventRepository()
        let financeRepo = MockFinanceSettingsRepository()
        let item = makeItem(name: "Milk")
        repo.items = [item]
        let vm = PantryViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            wasteEventRepository: wasteRepo,
            financeSettingsRepository: financeRepo
        )

        await vm.loadItems()
        vm.markFinished(item)
        await vm.confirmRemoveFromList()

        #expect(vm.items.isEmpty)
        #expect(wasteRepo.events.isEmpty)
    }

    @Test func saveWasteEventUsesExpiredSource() async {
        let repo = MockPantryRepository()
        let wasteRepo = MockWasteEventRepository()
        let financeRepo = MockFinanceSettingsRepository()
        let item = makeItem(name: "Yogurt")
        repo.items = [item]
        let vm = PantryViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            wasteEventRepository: wasteRepo,
            financeSettingsRepository: financeRepo
        )

        await vm.loadItems()
        vm.markFinished(item)
        vm.beginExpiredRemoval()
        await vm.saveWasteEvent(skipCost: true)

        #expect(wasteRepo.events.count == 1)
        #expect(wasteRepo.events.first?.source == WasteEventSource.expired.rawValue)
    }

    @Test func saveWasteEventUsesWasteSource() async {
        let repo = MockPantryRepository()
        let wasteRepo = MockWasteEventRepository()
        let financeRepo = MockFinanceSettingsRepository()
        let item = makeItem(name: "Bread")
        repo.items = [item]
        let vm = PantryViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            wasteEventRepository: wasteRepo,
            financeSettingsRepository: financeRepo
        )

        await vm.loadItems()
        vm.markFinished(item)
        vm.beginWasteRemoval()
        await vm.saveWasteEvent(skipCost: true)

        #expect(wasteRepo.events.count == 1)
        #expect(wasteRepo.events.first?.source == WasteEventSource.waste.rawValue)
    }
}

@MainActor
struct AddEditPantryItemViewModelMergeTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makePantryItem(name: String, quantity: Double, unit: UnitType = .pcs, expiryDate: Date? = nil) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: name,
            quantity: quantity,
            unit: unit,
            category: "Other",
            expiryDate: expiryDate,
            costPerUnitMinor: nil,
            lowStockThreshold: 1,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            archived: false
        )
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    @Test func saveMergesWhenMatchingNameUnitNoExpiry() async {
        let repo = MockPantryRepository()
        repo.items = [makePantryItem(name: "Rice", quantity: 2, unit: .pcs)]
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId
        )
        vm.name = "Rice"
        vm.quantity = "1"
        vm.selectedUnit = .pcs
        vm.hasExpiry = false

        let result = await vm.save()
        #expect(result == true)
        #expect(repo.items.count == 1)
        #expect(repo.items.first?.quantity == 3)
    }

    @Test func saveCreatesNewWhenDifferentUnit() async {
        let repo = MockPantryRepository()
        repo.items = [makePantryItem(name: "Rice", quantity: 2, unit: .pcs)]
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId
        )
        vm.name = "Rice"
        vm.quantity = "1"
        vm.selectedUnit = .kg
        vm.hasExpiry = false

        let result = await vm.save()
        #expect(result == true)
        #expect(repo.items.count == 2)
    }

    @Test func saveCreatesNewWhenHasExpiry() async {
        let repo = MockPantryRepository()
        repo.items = [makePantryItem(name: "Rice", quantity: 2, unit: .pcs)]
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId
        )
        vm.name = "Rice"
        vm.quantity = "1"
        vm.selectedUnit = .pcs
        vm.hasExpiry = true
        vm.expiryDate = Date.now.addingTimeInterval(7 * 24 * 60 * 60)

        let result = await vm.save()
        #expect(result == true)
        #expect(repo.items.count == 2)
    }

    @Test func initPrefillsFromBarcodeScan() {
        let repo = MockPantryRepository()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            barcodePrefillName: "Oat milk",
            barcodePrefillCategory: "Dairy"
        )
        #expect(vm.name == "Oat milk")
        #expect(vm.category == "Dairy")
        #expect(vm.customCategory.isEmpty)
    }

    @Test func initMapsUnknownBarcodeCategoryToCustom() {
        let repo = MockPantryRepository()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            barcodePrefillName: "Item",
            barcodePrefillCategory: "Canned"
        )
        #expect(vm.name == "Item")
        #expect(vm.category == "Custom")
        #expect(vm.customCategory == "Canned")
    }

    @Test func saveCreatesNewWithUploadedPhotoPath() async {
        let repo = MockPantryRepository()
        let photoStorage = MockPantryPhotoStorage()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            photoStorage: photoStorage
        )
        vm.name = "Tomatoes"
        vm.quantity = "1"
        vm.selectedUnit = .pcs
        vm.hasExpiry = false
        vm.recognizedPhotoPreview = makeTestImage()

        let result = await vm.save()

        #expect(result == true)
        #expect(repo.items.count == 1)
        #expect(repo.items.first?.photoPath != nil)
        #expect(photoStorage.uploadedPaths.count == 1)
    }

    @Test func saveMergesAndWritesPhotoPathWhenMatchExists() async {
        let repo = MockPantryRepository()
        repo.items = [makePantryItem(name: "Rice", quantity: 2, unit: .pcs)]
        let photoStorage = MockPantryPhotoStorage()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            photoStorage: photoStorage
        )
        vm.name = "Rice"
        vm.quantity = "1"
        vm.selectedUnit = .pcs
        vm.hasExpiry = false
        vm.recognizedPhotoPreview = makeTestImage()

        let result = await vm.save()

        #expect(result == true)
        #expect(repo.items.count == 1)
        #expect(repo.items.first?.quantity == 3)
        #expect(repo.items.first?.photoPath != nil)
        #expect(photoStorage.uploadedPaths.count == 1)
    }

    @Test func applyPhotoRecognitionResultStoresTopSuggestions() {
        let repo = MockPantryRepository()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId
        )
        let result = ProductRecognitionResult(
            suggestedName: "Tomato",
            suggestions: ["Tomato", "Apple", "Orange"],
            category: "Vegetables",
            confidence: 0.72,
            isLikelyFood: true
        )

        vm.applyPhotoRecognitionResult(result)

        #expect(vm.name == "Tomato")
        #expect(vm.photoRecognitionSuggestions == ["Tomato", "Apple", "Orange"])
    }

    @Test func applyPhotoRecognitionSuggestionOverridesName() {
        let repo = MockPantryRepository()
        let vm = AddEditPantryItemViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId
        )
        vm.name = "Tomato"
        vm.photoRecognitionSuggestions = ["Tomato", "Apple", "Orange"]

        vm.applyPhotoRecognitionSuggestion("Apple")

        #expect(vm.name == "Apple")
        #expect(vm.photoRecognitionHintIsError == false)
    }
}
