import Testing
import Foundation
@testable import GrubShelf

struct ShoppingListAddBehaviorTests {
    private func pantryItem(name: String, quantity: Double = 2, unit: UnitType = .l) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: name,
            quantity: quantity,
            unit: unit,
            category: "Beverages",
            storageLocation: .fridge,
            expiryDate: nil,
            costPerUnitMinor: nil,
            lowStockThreshold: 1,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: false
        )
    }

    @Test func pantryMatchFindsByName() {
        let pantry = pantryItem(name: "Coconut Water", quantity: 3, unit: .l)
        let match = ShoppingListAddBehavior.pantryMatch(in: [pantry], name: "coconut water")
        #expect(match?.name == "Coconut Water")
    }

    @Test func pantryMatchIgnoresArchived() {
        var pantry = pantryItem(name: "Water")
        pantry.archived = true
        #expect(ShoppingListAddBehavior.pantryMatch(in: [pantry], name: "Water") == nil)
    }

    @Test func inPantryInlineMessageIncludesQuantityLeft() {
        let pantry = pantryItem(name: "Water", quantity: 4, unit: .l)
        let message = ShoppingListAddBehavior.inPantryInlineMessage(for: pantry)
        #expect(message.contains("Water"))
        #expect(message.contains("pantry"))
        #expect(message.contains("left"))
    }
}
