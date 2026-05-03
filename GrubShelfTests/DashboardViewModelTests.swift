import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct DashboardViewModelTests {
    private let householdId = UUID()

    private func makeItem(
        state: ItemState,
        category: String = "Dairy"
    ) -> PantryItem {
        let expiry: Date? = switch state {
        case .expired: Date.now.addingTimeInterval(-86400)
        case .expiringSoon: Date.now.addingTimeInterval(86400)
        default: nil
        }
        return PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: "Item",
            quantity: state == .archived ? 0 : 10,
            unit: .pcs,
            category: category,
            expiryDate: expiry,
            costPerUnitMinor: nil,
            lowStockThreshold: state == .lowStock ? 10 : 0,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: state == .archived
        )
    }

    private func makeShoppingItem(completed: Bool) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: nil,
            name: "Shop item",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: completed,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func loadDataPopulatesAllCounts() async {
        let pantryRepo = MockPantryRepository()
        pantryRepo.items = [
            makeItem(state: .active, category: "Dairy"),
            makeItem(state: .active, category: "Produce"),
            makeItem(state: .lowStock, category: "Dairy"),
            makeItem(state: .expiringSoon, category: "Meat"),
            makeItem(state: .expired, category: "Bakery"),
        ]

        let shoppingRepo = MockShoppingRepository()
        shoppingRepo.items = [
            makeShoppingItem(completed: true),
            makeShoppingItem(completed: false),
            makeShoppingItem(completed: true),
        ]

        let vm = DashboardViewModel(
            pantryRepository: pantryRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId
        )

        await vm.loadData()

        #expect(vm.totalPantryItems == 5)
        #expect(vm.categoriesCount == 4)
        #expect(vm.lowStockCount == 1)
        #expect(vm.expiringItems.count == 2) // expiringSoon + expired
        #expect(vm.shoppingTotal == 3)
        #expect(vm.shoppingCompleted == 2)
    }

    @Test func completionPercentageCalculation() async {
        let pantryRepo = MockPantryRepository()
        let shoppingRepo = MockShoppingRepository()
        shoppingRepo.items = [
            makeShoppingItem(completed: true),
            makeShoppingItem(completed: true),
            makeShoppingItem(completed: false),
            makeShoppingItem(completed: false),
        ]

        let vm = DashboardViewModel(
            pantryRepository: pantryRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId
        )

        await vm.loadData()
        #expect(vm.completionPercentage == 50.0)
    }

    @Test func completionPercentageZeroWhenEmpty() {
        let vm = DashboardViewModel(
            pantryRepository: MockPantryRepository(),
            shoppingRepository: MockShoppingRepository(),
            householdId: householdId
        )
        #expect(vm.completionPercentage == 0)
    }

    @Test func overviewHeadlineIsNonEmpty() {
        let vm = DashboardViewModel(
            pantryRepository: MockPantryRepository(),
            shoppingRepository: MockShoppingRepository(),
            householdId: householdId
        )
        #expect(!vm.overviewHeadline.isEmpty)
    }

    @Test func actionPillCounts() async {
        let pantryRepo = MockPantryRepository()
        pantryRepo.items = [
            makeItem(state: .expiringSoon),
            makeItem(state: .expired),
            makeItem(state: .lowStock),
            makeItem(state: .active),
        ]

        let shoppingRepo = MockShoppingRepository()
        shoppingRepo.items = [
            makeShoppingItem(completed: true),
            makeShoppingItem(completed: false),
            makeShoppingItem(completed: false),
        ]

        let vm = DashboardViewModel(
            pantryRepository: pantryRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId
        )

        await vm.loadData()

        #expect(vm.expiringCount == 2)
        #expect(vm.lowStockCount == 1)
        #expect(vm.pendingShoppingCount == 2)
    }
}
