import Testing
import Foundation
@testable import FoodPan

@MainActor
struct PantryViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makeItem(
        name: String = "Milk",
        category: String = "Dairy",
        state: ItemState = .active
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
        vm.selectedFilter = .all
        #expect(vm.filteredItems.count == 2)
    }

    @Test func filteredItemsExpiring() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", state: .active),
            makeItem(name: "Expiring Yogurt", state: .expiringSoon),
            makeItem(name: "Old Bread", state: .expired),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedFilter = .expiring
        #expect(vm.filteredItems.count == 2)
    }

    @Test func filteredItemsLowStock() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", state: .active),
            makeItem(name: "Salt", state: .lowStock),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        vm.selectedFilter = .lowStock
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.name == "Salt")
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

    @Test func groupedByCategory() async {
        let repo = MockPantryRepository()
        repo.items = [
            makeItem(name: "Milk", category: "Dairy"),
            makeItem(name: "Cheese", category: "Dairy"),
            makeItem(name: "Eggs", category: "Protein"),
        ]
        let vm = PantryViewModel(repository: repo, householdId: householdId, userId: userId)
        await vm.loadItems()
        let grouped = vm.groupedByCategory
        #expect(grouped.count == 2)
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
}
