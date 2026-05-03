import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct ShoppingListViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()
    private let listId = UUID()
    private let mockCatalog = MockGroceryCatalogRepository()

    private func makeItem(name: String = "Apples", completed: Bool = false) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: name,
            quantity: 1,
            unit: nil,
            category: nil,
            completed: completed,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func loadItemsPopulates() async {
        let repo = MockShoppingRepository()
        repo.items = [makeItem(name: "Apples"), makeItem(name: "Bread")]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        #expect(vm.items.count == 2)
    }

    @Test func pendingItemsFilterUncompleted() async {
        let repo = MockShoppingRepository()
        repo.items = [
            makeItem(name: "Apples", completed: false),
            makeItem(name: "Done", completed: true),
        ]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        #expect(vm.pendingItems.count == 1)
        #expect(vm.completedItems.count == 1)
    }

    @Test func addItemAppendsAndClearsField() async {
        let repo = MockShoppingRepository()
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        vm.newItemName = "Bananas"
        await vm.addItem()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.name == "Bananas")
        #expect(vm.items.first?.listId == listId)
        #expect(vm.newItemName.isEmpty)
    }

    @Test func addItemIgnoresEmpty() async {
        let repo = MockShoppingRepository()
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        vm.newItemName = "   "
        await vm.addItem()
        #expect(vm.items.isEmpty)
    }

    @Test func toggleCompleteFlipsState() async {
        let repo = MockShoppingRepository()
        let item = makeItem(name: "Apples", completed: false)
        repo.items = [item]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        await vm.toggleComplete(vm.items[0])
        #expect(vm.items[0].completed == true)
    }

    @Test func deleteItemRemoves() async {
        let repo = MockShoppingRepository()
        let item = makeItem(name: "Apples")
        repo.items = [item]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        await vm.deleteItem(vm.items[0])
        #expect(vm.items.isEmpty)
    }

    @Test func markAllCompleteMarksAll() async {
        let repo = MockShoppingRepository()
        repo.items = [
            makeItem(name: "A", completed: false),
            makeItem(name: "B", completed: false),
            makeItem(name: "C", completed: true),
        ]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        await vm.markAllComplete()
        #expect(vm.pendingItems.isEmpty)
        #expect(vm.completedItems.count == 3)
    }

    @Test func allItemsCompletedWhenAllDone() async {
        let repo = MockShoppingRepository()
        repo.items = [
            makeItem(name: "A", completed: true),
            makeItem(name: "B", completed: true),
        ]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        #expect(vm.allItemsCompleted == true)
    }

    @Test func allItemsCompletedFalseWhenPending() async {
        let repo = MockShoppingRepository()
        repo.items = [
            makeItem(name: "A", completed: false),
            makeItem(name: "B", completed: true),
        ]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        #expect(vm.allItemsCompleted == false)
    }

    @Test func addCatalogItemAddsWithCategory() async {
        let repo = MockShoppingRepository()
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        let catalogItem = GroceryCatalogItem(
            catalogItemId: UUID(),
            name: "Apple",
            defaultCategory: "Fruits",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )
        await vm.addCatalogItem(catalogItem)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.name == "Apple")
        #expect(vm.items.first?.category == "Fruits")
        #expect(vm.items.first?.unit == .pcs)
    }

    @Test func addItemIncrementsExistingQuantity() async {
        let repo = MockShoppingRepository()
        repo.items = [makeItem(name: "Bananas")]
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        await vm.loadItems()
        vm.newItemName = "Bananas"
        await vm.addItem()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.quantity == 2)
    }

    @Test func addItemRacePrevention() async {
        let repo = MockShoppingRepository()
        let vm = ShoppingListViewModel(repository: repo, catalogRepository: mockCatalog, householdId: householdId, userId: userId, listId: listId)
        vm.newItemName = "Milk"
        await vm.addItem()
        vm.newItemName = "Milk"
        await vm.addItem()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.quantity == 2)
    }
}
