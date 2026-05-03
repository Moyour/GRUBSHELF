import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct ShoppingAuditViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()

    private func makePantryItem(
        name: String,
        category: String = "Other",
        quantity: Double = 2,
        unit: UnitType = .pcs
    ) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: name,
            quantity: quantity,
            unit: unit,
            category: category,
            lowStockThreshold: 1,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            archived: false
        )
    }

    private func makeShoppingItem(name: String, quantity: Double = 1) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: nil,
            name: name,
            quantity: quantity,
            unit: .pcs,
            category: nil,
            completed: true,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
    }

    // MARK: - Matching

    @Test func matchesByExactName() {
        let pantry = [makePantryItem(name: "Rice")]
        let shopping = [makeShoppingItem(name: "Rice")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.hasMatches)
        #expect(vm.matchedEntries.count == 1)
        #expect(vm.unmatchedEntries.isEmpty)
    }

    @Test func matchesCaseInsensitive() {
        let pantry = [makePantryItem(name: "Basmati Rice")]
        let shopping = [makeShoppingItem(name: "basmati rice")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.hasMatches)
        #expect(vm.matchedEntries.count == 1)
    }

    @Test func noMatchForDifferentNames() {
        let pantry = [makePantryItem(name: "Rice")]
        let shopping = [makeShoppingItem(name: "Pasta")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(!vm.hasMatches)
        #expect(vm.matchedEntries.isEmpty)
        #expect(vm.unmatchedEntries.count == 1)
    }

    @Test func skipsArchivedPantryItems() {
        var archived = makePantryItem(name: "Rice")
        archived = PantryItem(
            itemId: archived.itemId,
            householdId: archived.householdId,
            name: archived.name,
            quantity: 0,
            unit: archived.unit,
            category: archived.category,
            storageLocation: archived.storageLocation,
            lowStockThreshold: archived.lowStockThreshold,
            createdBy: archived.createdBy,
            createdAt: archived.createdAt,
            updatedAt: archived.updatedAt,
            archived: true
        )
        let shopping = [makeShoppingItem(name: "Rice")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: [archived])

        #expect(!vm.hasMatches)
    }

    @Test func doesNotDoublMatchSamePantryItem() {
        let pantry = [makePantryItem(name: "Milk")]
        let shopping = [makeShoppingItem(name: "Milk"), makeShoppingItem(name: "Milk")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.matchedEntries.count == 1)
        #expect(vm.unmatchedEntries.count == 1)
    }

    // MARK: - Smart Defaults

    @Test func perishableDefaultsToUsedAll() {
        let pantry = [makePantryItem(name: "Chicken", category: "Meat")]
        let shopping = [makeShoppingItem(name: "Chicken")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.entries.first?.resolution == .usedAll)
    }

    @Test func stapleDefaultsToStillHaveSome() {
        let pantry = [makePantryItem(name: "Rice", category: "Grains")]
        let shopping = [makeShoppingItem(name: "Rice")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.entries.first?.resolution == .stillHaveSome)
    }

    @Test func allPerishableCategoriesDetected() {
        let categories = ["Fruits", "Vegetables", "Dairy", "Meat", "Seafood", "Bakery"]
        for cat in categories {
            #expect(ShoppingAuditViewModel.smartDefault(for: cat) == .usedAll, "Expected .usedAll for \(cat)")
        }
    }

    @Test func nonPerishableDefaultsToStillHaveSome() {
        let categories = ["Grains", "Canned", "Condiments", "Frozen", "Snacks", "Beverages"]
        for cat in categories {
            #expect(ShoppingAuditViewModel.smartDefault(for: cat) == .stillHaveSome, "Expected .stillHaveSome for \(cat)")
        }
    }

    // MARK: - Mixed Entries

    @Test func mixedMatchedAndUnmatched() {
        let pantry = [makePantryItem(name: "Eggs", category: "Dairy")]
        let shopping = [makeShoppingItem(name: "Eggs"), makeShoppingItem(name: "Avocado")]
        let vm = ShoppingAuditViewModel(transferableItems: shopping, pantryItems: pantry)

        #expect(vm.matchedEntries.count == 1)
        #expect(vm.unmatchedEntries.count == 1)
        #expect(vm.entries.count == 2)
    }

    @Test func emptyInputsProducesNoEntries() {
        let vm = ShoppingAuditViewModel(transferableItems: [], pantryItems: [])
        #expect(vm.entries.isEmpty)
        #expect(!vm.hasMatches)
    }
}
