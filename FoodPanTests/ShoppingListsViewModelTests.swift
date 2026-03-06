import Testing
import Foundation
@testable import FoodPan

@MainActor
struct ShoppingListsViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makeList(name: String = "Weekly") -> ShoppingList {
        ShoppingList(
            listId: UUID(),
            householdId: householdId,
            name: name,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )
    }

    @Test func loadListsPopulates() async {
        let listRepo = MockShoppingListRepository()
        listRepo.lists = [makeList(name: "Weekly"), makeList(name: "Party")]
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        #expect(vm.lists.count == 2)
    }

    @Test func createListAddsAndClearsField() async {
        let listRepo = MockShoppingListRepository()
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        vm.newListName = "Groceries"
        await vm.createList()
        #expect(vm.lists.count == 1)
        #expect(vm.lists.first?.name == "Groceries")
        #expect(vm.newListName.isEmpty)
    }

    @Test func createListIgnoresEmpty() async {
        let listRepo = MockShoppingListRepository()
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        vm.newListName = "   "
        await vm.createList()
        #expect(vm.lists.isEmpty)
    }

    @Test func deleteListRemoves() async {
        let listRepo = MockShoppingListRepository()
        let list = makeList(name: "Weekly")
        listRepo.lists = [list]
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        #expect(vm.lists.count == 1)
        await vm.deleteList(vm.lists[0])
        #expect(vm.lists.isEmpty)
    }
}
