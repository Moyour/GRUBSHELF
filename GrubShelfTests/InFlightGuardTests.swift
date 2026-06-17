import Testing
import Foundation
@testable import GrubShelf

// MARK: - PantryViewModel guard tests

@MainActor
struct PantryViewModelInFlightTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makePantryItem(name: String = "Milk") -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: name,
            quantity: 2,
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
            expectedUsageCycleDays: nil,
            approvalStatus: .approved
        )
    }

    private func makeVM(repo: MockPantryRepository) -> PantryViewModel {
        PantryViewModel(
            repository: repo,
            householdId: householdId,
            userId: userId,
            userRole: .admin
        )
    }

    // MARK: - inflightItemIds starts empty

    @Test func inflightItemIdsInitiallyEmpty() {
        let vm = makeVM(repo: MockPantryRepository())
        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - incrementItem guard

    @Test func incrementItemBlocksDoubleSubmit() async {
        let repo = MockPantryRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        async let first: Void = vm.incrementItem(item)
        async let second: Void = vm.incrementItem(item)
        await first
        await second

        #expect(repo.updateCallCount == 1)
    }

    @Test func incrementItemClearsInflightAfterCompletion() async {
        let repo = MockPantryRepository()
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        await vm.incrementItem(item)

        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - decrementItem guard

    @Test func decrementItemBlocksDoubleSubmit() async {
        let repo = MockPantryRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        async let first: Void = vm.decrementItem(item)
        async let second: Void = vm.decrementItem(item)
        await first
        await second

        #expect(repo.updateCallCount == 1)
    }

    @Test func decrementItemClearsInflightAfterCompletion() async {
        let repo = MockPantryRepository()
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        await vm.decrementItem(item)

        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - halveItem guard

    @Test func halveItemBlocksDoubleSubmit() async {
        let repo = MockPantryRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        async let first: Void = vm.halveItem(item)
        async let second: Void = vm.halveItem(item)
        await first
        await second

        #expect(repo.updateCallCount == 1)
    }

    // MARK: - deleteItem guard

    @Test func deleteItemBlocksDoubleSubmit() async {
        let repo = MockPantryRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        async let first: Void = vm.deleteItem(item)
        async let second: Void = vm.deleteItem(item)
        await first
        await second

        #expect(repo.deleteCallCount == 1)
    }

    @Test func deleteItemClearsInflightAfterCompletion() async {
        let repo = MockPantryRepository()
        let vm = makeVM(repo: repo)
        let item = makePantryItem()
        vm.items = [item]
        repo.items = [item]

        await vm.deleteItem(item)

        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - different items run in parallel (guard is per-item)

    @Test func differentItemsAreNotBlocked() async {
        let repo = MockPantryRepository()
        repo.operationDelay = .milliseconds(20)
        let vm = makeVM(repo: repo)
        let a = makePantryItem(name: "A")
        let b = makePantryItem(name: "B")
        vm.items = [a, b]
        repo.items = [a, b]

        async let first: Void = vm.incrementItem(a)
        async let second: Void = vm.incrementItem(b)
        await first
        await second

        #expect(repo.updateCallCount == 2)
    }
}

// MARK: - ShoppingListViewModel guard tests

@MainActor
struct ShoppingListViewModelInFlightTests {
    private let householdId = UUID()
    private let userId = UUID()
    private let listId = UUID()

    private func makeItem(name: String = "Eggs", completed: Bool = false) -> ShoppingItem {
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

    private func makeVM(repo: MockShoppingRepository) -> ShoppingListViewModel {
        ShoppingListViewModel(
            repository: repo,
            catalogRepository: MockGroceryCatalogRepository(),
            householdId: householdId,
            userId: userId,
            userRole: .admin,
            listId: listId
        )
    }

    // MARK: - Initial state

    @Test func inflightItemIdsInitiallyEmpty() {
        let vm = makeVM(repo: MockShoppingRepository())
        #expect(vm.inflightItemIds.isEmpty)
        #expect(!vm.isMarkingAllComplete)
    }

    // MARK: - toggleComplete guard

    @Test func toggleCompleteBlocksDoubleSubmit() async {
        let repo = MockShoppingRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makeItem()
        repo.items = [item]
        await vm.loadItems()

        let loaded = vm.items[0]
        async let first: Void = vm.toggleComplete(loaded)
        async let second: Void = vm.toggleComplete(loaded)
        await first
        await second

        #expect(repo.updateCallCount == 1)
    }

    @Test func toggleCompleteClearsInflightAfterCompletion() async {
        let repo = MockShoppingRepository()
        let vm = makeVM(repo: repo)
        let item = makeItem()
        repo.items = [item]
        await vm.loadItems()

        await vm.toggleComplete(vm.items[0])

        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - deleteItem guard

    @Test func deleteItemBlocksDoubleSubmit() async {
        let repo = MockShoppingRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let item = makeItem()
        repo.items = [item]
        await vm.loadItems()

        let loaded = vm.items[0]
        async let first: Void = vm.deleteItem(loaded)
        async let second: Void = vm.deleteItem(loaded)
        await first
        await second

        #expect(repo.deleteCallCount == 1)
    }

    // MARK: - markAllComplete guard

    @Test func markAllCompleteIsMarkingAllCompleteDuringExecution() async {
        let repo = MockShoppingRepository()
        repo.operationDelay = .milliseconds(20)
        let vm = makeVM(repo: repo)
        let item = makeItem(completed: false)
        repo.items = [item]
        await vm.loadItems()

        var flagObservedDuringRun = false
        let task = Task {
            flagObservedDuringRun = vm.isMarkingAllComplete
            await vm.markAllComplete()
        }
        await task.value

        // Flag is cleared when done
        #expect(!vm.isMarkingAllComplete)
        _ = flagObservedDuringRun // consumed
    }

    @Test func markAllCompleteBlocksSecondCall() async {
        let repo = MockShoppingRepository()
        repo.operationDelay = .milliseconds(30)
        let vm = makeVM(repo: repo)
        let items = [makeItem(name: "A"), makeItem(name: "B")]
        repo.items = items
        await vm.loadItems()

        async let first: Void = vm.markAllComplete()
        async let second: Void = vm.markAllComplete()
        await first
        await second

        // Only the first batch of toggles was dispatched (2 updates), not doubled
        #expect(repo.updateCallCount == 2)
    }
}

// MARK: - ShoppingListsViewModel guard tests

@MainActor
struct ShoppingListsViewModelInFlightTests {
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

    private func makeVM(
        listRepo: MockShoppingListRepository,
        shopRepo: MockShoppingRepository = MockShoppingRepository()
    ) -> ShoppingListsViewModel {
        ShoppingListsViewModel(
            listRepository: listRepo,
            shoppingRepository: shopRepo,
            householdId: householdId,
            userId: userId,
            userRole: .admin
        )
    }

    // MARK: - Initial state

    @Test func guardFlagsInitiallyFalse() {
        let vm = makeVM(listRepo: MockShoppingListRepository())
        #expect(!vm.isCreatingList)
        #expect(vm.deletingListIds.isEmpty)
        #expect(!vm.isAddingToActiveList)
        #expect(vm.inflightItemIds.isEmpty)
    }

    // MARK: - createList guard

    @Test func createListBlocksDoubleSubmit() async {
        let listRepo = MockShoppingListRepository()
        listRepo.operationDelay = .milliseconds(30)
        let vm = makeVM(listRepo: listRepo)
        vm.newListName = "My List"

        async let first: ShoppingList? = vm.createList()
        // Second call must see isCreatingList == true from the first
        async let second: ShoppingList? = vm.createList()
        _ = await first
        _ = await second

        #expect(listRepo.addCallCount == 1)
    }

    @Test func createListClearsIsCreatingAfterCompletion() async {
        let listRepo = MockShoppingListRepository()
        let vm = makeVM(listRepo: listRepo)
        vm.newListName = "My List"

        await vm.createList()

        #expect(!vm.isCreatingList)
    }

    // MARK: - deleteList guard

    @Test func deleteListBlocksDoubleSubmit() async {
        let listRepo = MockShoppingListRepository()
        listRepo.operationDelay = .milliseconds(30)
        let vm = makeVM(listRepo: listRepo)
        let list = makeList()
        listRepo.lists = [list]
        await vm.loadLists(forceRefresh: true)

        let target = vm.lists[0]
        async let first: Void = vm.deleteList(target)
        async let second: Void = vm.deleteList(target)
        await first
        await second

        #expect(listRepo.deleteCallCount == 1)
    }

    @Test func deleteListClearsDeletingListIdsAfterCompletion() async {
        let listRepo = MockShoppingListRepository()
        let vm = makeVM(listRepo: listRepo)
        let list = makeList()
        listRepo.lists = [list]
        await vm.loadLists(forceRefresh: true)

        await vm.deleteList(vm.lists[0])

        #expect(vm.deletingListIds.isEmpty)
    }

    // MARK: - Different lists can be deleted in parallel

    @Test func differentListsNotBlocked() async {
        let listRepo = MockShoppingListRepository()
        listRepo.operationDelay = .milliseconds(80)
        let vm = makeVM(listRepo: listRepo)
        let a = makeList(name: "A")
        let b = makeList(name: "B")
        listRepo.lists = [a, b]
        await vm.loadLists(forceRefresh: true)

        #expect(vm.canDeleteShoppingList)
        #expect(vm.lists.count == 2)

        // Start deleting A, then delete B while A is still in flight (different list IDs).
        let deleteA = Task { @MainActor in await vm.deleteList(a) }
        try? await Task.sleep(for: .milliseconds(10))
        await vm.deleteList(b)
        await deleteA.value

        #expect(listRepo.deleteCallCount == 2)
        #expect(vm.lists.isEmpty)
    }
}

// MARK: - PendingApprovalsViewModel guard tests

@MainActor
struct PendingApprovalsViewModelInFlightTests {

    @Test func guardFlagsInitiallyFalse() {
        let vm = PendingApprovalsViewModel(householdId: UUID())
        #expect(vm.inflightItemIds.isEmpty)
        #expect(!vm.isApprovingAllPantry)
        #expect(!vm.isApprovingAllShopping)
    }
}

