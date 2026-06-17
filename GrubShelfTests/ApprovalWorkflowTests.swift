import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct ApprovalWorkflowTests {
    private func makePantryItem(
        approvalStatus: ApprovalStatus = .approved,
        createdBy: UUID = UUID()
    ) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: "Milk",
            quantity: 1,
            unit: .l,
            category: "Dairy",
            lowStockThreshold: 1,
            createdBy: createdBy,
            createdAt: .now,
            updatedAt: .now,
            archived: false,
            approvalStatus: approvalStatus
        )
    }

    @Test func approvedItemsFilterExcludesPending() {
        let userId = UUID()
        let approved = makePantryItem(approvalStatus: .approved)
        let pending = makePantryItem(approvalStatus: .pending, createdBy: userId)
        let repo = MockPantryRepository()
        repo.items = [approved, pending]
        let vm = PantryViewModel(
            repository: repo,
            householdId: UUID(),
            userId: userId,
            userRole: .member
        )
        vm.items = [approved, pending]
        #expect(vm.approvedItems.count == 1)
        #expect(vm.approvedItems.first?.itemId == approved.itemId)
        #expect(vm.myPendingItems.count == 1)
    }

    @Test func memberCannotModifyApprovedItem() {
        let userId = UUID()
        let item = makePantryItem(approvalStatus: .approved, createdBy: UUID())
        let vm = PantryViewModel(
            repository: MockPantryRepository(),
            householdId: UUID(),
            userId: userId,
            userRole: .member
        )
        #expect(vm.canModifyItem(item) == false)
    }

    @Test func memberCanModifyOwnPendingItem() {
        let userId = UUID()
        let item = makePantryItem(approvalStatus: .pending, createdBy: userId)
        let vm = PantryViewModel(
            repository: MockPantryRepository(),
            householdId: UUID(),
            userId: userId,
            userRole: .member
        )
        #expect(vm.canModifyItem(item) == true)
    }

    @Test func adminCanModifyApprovedItem() {
        let item = makePantryItem(approvalStatus: .approved)
        let vm = PantryViewModel(
            repository: MockPantryRepository(),
            householdId: UUID(),
            userId: UUID(),
            userRole: .admin
        )
        #expect(vm.canModifyItem(item) == true)
    }

    @Test func pendingApprovalCountsTotal() {
        let counts = PendingApprovalCounts(pendingPantryCount: 2, pendingShoppingCount: 3)
        #expect(counts.total == 5)
    }

    @Test func newlyPendingItemsDetectsUnseenSubmissions() {
        let knownId = UUID()
        let newPantryId = UUID()
        let newShoppingId = UUID()

        let knownItem = makePantryItem(approvalStatus: .pending)
        var knownPantry = knownItem
        // Re-create with fixed id for the "already known" pending item
        knownPantry = PantryItem(
            itemId: knownId,
            householdId: knownItem.householdId,
            name: knownItem.name,
            quantity: knownItem.quantity,
            unit: knownItem.unit,
            category: knownItem.category,
            lowStockThreshold: knownItem.lowStockThreshold,
            createdBy: knownItem.createdBy,
            createdAt: knownItem.createdAt,
            updatedAt: knownItem.updatedAt,
            archived: knownItem.archived,
            approvalStatus: .pending
        )

        var newPantry = makePantryItem(approvalStatus: .pending)
        newPantry = PantryItem(
            itemId: newPantryId,
            householdId: newPantry.householdId,
            name: "Beans",
            quantity: newPantry.quantity,
            unit: newPantry.unit,
            category: newPantry.category,
            lowStockThreshold: newPantry.lowStockThreshold,
            createdBy: newPantry.createdBy,
            createdAt: newPantry.createdAt,
            updatedAt: newPantry.updatedAt,
            archived: newPantry.archived,
            approvalStatus: .pending
        )

        let shopping = [
            ShoppingItem(
                itemId: newShoppingId,
                householdId: UUID(),
                listId: nil,
                name: "Soap",
                quantity: 1,
                unit: nil,
                category: nil,
                completed: false,
                createdBy: UUID(),
                createdAt: .now,
                updatedAt: .now,
                approvalStatus: .pending
            )
        ]

        let alerts = ApprovalNotificationTracker.newlyPendingItems(
            knownPendingIDs: [knownId],
            pantryItems: [knownPantry, newPantry],
            shoppingItems: shopping
        )

        #expect(alerts.count == 2)
        #expect(alerts.contains(where: { $0.itemId == newPantryId && $0.itemType == "pantry" }))
        #expect(alerts.contains(where: { $0.itemId == newShoppingId && $0.itemType == "shopping" }))
    }
}
