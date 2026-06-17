import Testing
import Foundation
@testable import GrubShelf

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
            userId: userId,
            userRole: .admin
        )
        vm.newListName = "Groceries"
        let created = await vm.createList()
        #expect(created != nil)
        #expect(created?.name == "Groceries")
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
            userId: userId,
            userRole: .admin
        )
        vm.newListName = "   "
        let created = await vm.createList()
        #expect(created == nil)
        #expect(vm.lists.isEmpty)
    }

    @Test func memberCannotDeleteList() async {
        let list = makeList()
        let listRepo = MockShoppingListRepository()
        listRepo.lists = [list]
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId,
            userRole: .member
        )
        await vm.deleteList(list)
        #expect(listRepo.lists.count == 1)
        #expect(!vm.canDeleteShoppingList)
    }

    @Test func memberCannotCreateList() async {
        let listRepo = MockShoppingListRepository()
        let shoppingRepo = MockShoppingRepository()
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId,
            userRole: .member
        )
        vm.newListName = "Groceries"
        let created = await vm.createList()
        #expect(created == nil)
        #expect(vm.lists.isEmpty)
        #expect(!vm.canCreateShoppingList)
    }

    @Test func hubSummaryCountsAllListsButExcludesTransferredFromItemTotals() {
        let transferred = ShoppingList(
            listId: UUID(),
            householdId: householdId,
            name: "Old trip",
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            transferred: true
        )
        let active = ShoppingList(
            listId: UUID(),
            householdId: householdId,
            name: "Weekly",
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )
        let counts: [UUID: (pending: Int, completed: Int)] = [
            transferred.listId: (3, 2),
            active.listId: (4, 1),
        ]
        let summary = ShoppingHubSummary.make(lists: [transferred, active], listItemCounts: counts)
        #expect(summary.listCount == 2)
        #expect(summary.pendingTotal == 4)
        #expect(summary.completedTotal == 1)
    }

    @Test func hubSummaryUsesZeroWhenListHasNoCountEntry() {
        let list = makeList(name: "Empty meta")
        let summary = ShoppingHubSummary.make(lists: [list], listItemCounts: [:])
        #expect(summary.listCount == 1)
        #expect(summary.pendingTotal == 0)
        #expect(summary.completedTotal == 0)
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
            userId: userId,
            userRole: .admin
        )
        await vm.loadLists()
        #expect(vm.lists.count == 1)
        await vm.deleteList(vm.lists[0])
        #expect(vm.lists.isEmpty)
    }

    @Test func homePrimaryListPreviewIncludesAllItemsSortedPendingFirst() async throws {
        let listRepo = MockShoppingListRepository()
        let primary = makeList(name: "Primary")
        listRepo.lists = [primary]
        let shoppingRepo = MockShoppingRepository()
        let mk: (String, Bool) -> ShoppingItem = { name, completed in
            ShoppingItem(
                itemId: UUID(),
                householdId: householdId,
                listId: primary.listId,
                name: name,
                quantity: 1,
                unit: nil,
                category: nil,
                completed: completed,
                transferred: false,
                createdBy: userId,
                createdAt: .now,
                updatedAt: .now
            )
        }
        // More than the old 4-row cap — all should appear
        shoppingRepo.items = [
            mk("Zebra", true),
            mk("Apple", false),
            mk("Mango", true),
            mk("Banana", false),
            mk("Citrus", false),
            mk("Pear", false),
        ]
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        let preview = try #require(vm.homePrimaryListPreview)
        #expect(preview.list.listId == primary.listId)
        #expect(preview.items.count == 6)
        let pending = preview.items.filter { !$0.completed }.map(\.name)
        let done = preview.items.filter(\.completed).map(\.name)
        #expect(pending == ["Apple", "Banana", "Citrus", "Pear"])
        #expect(done == ["Mango", "Zebra"])
    }

    @Test func homePrimaryListPreviewOmitsTransferredItems() async {
        let listRepo = MockShoppingListRepository()
        let primary = makeList(name: "Primary")
        listRepo.lists = [primary]
        let shoppingRepo = MockShoppingRepository()
        let kept = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: primary.listId,
            name: "Kept",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
        let gone = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: primary.listId,
            name: "Gone",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            transferred: true,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
        shoppingRepo.items = [kept, gone]
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        let preview = vm.homePrimaryListPreview
        #expect(preview?.items.count == 1)
        #expect(preview?.items.first?.name == "Kept")
    }

    private func makeItem(
        listId: UUID,
        name: String,
        completed: Bool
    ) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: name,
            quantity: 1,
            unit: .pcs,
            category: nil,
            completed: completed,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
    }

    // Partial transfer: transferable items exist as soon as any completed items are present.
    @Test func hasActiveTransferableItemsTrueWhenSomeItemsCompleted() async {
        let list = makeList()
        let listRepo = MockShoppingListRepository()
        listRepo.lists = [list]
        let shoppingRepo = MockShoppingRepository()
        shoppingRepo.items = [
            makeItem(listId: list.listId, name: "Milk", completed: false),
            makeItem(listId: list.listId, name: "Bread", completed: true),
        ]
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        await vm.loadActiveListItems()
        #expect(!vm.transferableActiveListItems.isEmpty)
        #expect(vm.hasActiveTransferableItems)
    }

    @Test func hasActiveTransferableItemsTrueWhenAllItemsCompleted() async {
        let list = makeList()
        let listRepo = MockShoppingListRepository()
        listRepo.lists = [list]
        let shoppingRepo = MockShoppingRepository()
        shoppingRepo.items = [
            makeItem(listId: list.listId, name: "Milk", completed: true),
            makeItem(listId: list.listId, name: "Bread", completed: true),
        ]
        let vm = ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId
        )
        await vm.loadLists()
        await vm.loadActiveListItems()
        #expect(vm.hasActiveTransferableItems)
    }
}
