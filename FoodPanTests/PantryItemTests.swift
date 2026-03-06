import Testing
import Foundation
@testable import FoodPan

struct PantryItemTests {
    private func makeItem(
        quantity: Double = 10,
        expiryDate: Date? = nil,
        lowStockThreshold: Double = 1,
        archived: Bool = false,
        name: String = "Milk",
        category: String = "Dairy",
        costPerUnitMinor: Int? = nil
    ) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: name,
            quantity: quantity,
            unit: .l,
            category: category,
            expiryDate: expiryDate,
            costPerUnitMinor: costPerUnitMinor,
            lowStockThreshold: lowStockThreshold,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: archived
        )
    }

    // MARK: - State Transitions

    @Test func activeState() {
        let item = makeItem()
        #expect(item.state == .active)
    }

    @Test func lowStockWhenAtThreshold() {
        let item = makeItem(quantity: 1, lowStockThreshold: 1)
        #expect(item.state == .lowStock)
    }

    @Test func lowStockWhenBelowThreshold() {
        let item = makeItem(quantity: 0.5, lowStockThreshold: 2)
        #expect(item.state == .lowStock)
    }

    @Test func expiringSoonWithin3Days() {
        let item = makeItem(expiryDate: Date.now.addingTimeInterval(2 * 24 * 60 * 60))
        #expect(item.state == .expiringSoon)
    }

    @Test func expiredWhenPastExpiry() {
        let item = makeItem(expiryDate: Date.now.addingTimeInterval(-1))
        #expect(item.state == .expired)
    }

    @Test func archivedWhenFlagged() {
        let item = makeItem(archived: true)
        #expect(item.state == .archived)
    }

    @Test func archivedWhenZeroQuantity() {
        let item = makeItem(quantity: 0)
        #expect(item.state == .archived)
    }

    // MARK: - Priority Ordering

    @Test func expiringSoonTakesPriorityOverLowStock() {
        let item = makeItem(
            quantity: 1,
            expiryDate: Date.now.addingTimeInterval(2 * 24 * 60 * 60),
            lowStockThreshold: 1
        )
        #expect(item.state == .expiringSoon)
    }

    @Test func expiredTakesPriorityOverExpiringSoon() {
        let item = makeItem(
            quantity: 1,
            expiryDate: Date.now.addingTimeInterval(-60),
            lowStockThreshold: 1
        )
        #expect(item.state == .expired)
    }

    @Test func archivedTakesPriorityOverExpired() {
        let item = makeItem(
            quantity: 0,
            expiryDate: Date.now.addingTimeInterval(-60),
            archived: true
        )
        #expect(item.state == .archived)
    }

    // MARK: - Validation

    @Test func validItemPasses() {
        let item = makeItem()
        #expect(item.validate().isEmpty)
    }

    @Test func emptyNameFails() {
        let item = makeItem(name: "")
        #expect(item.validate().contains { $0.contains("Name") })
    }

    @Test func longNameFails() {
        let item = makeItem(name: String(repeating: "a", count: 121))
        #expect(item.validate().contains { $0.contains("Name") })
    }

    @Test func negativeQuantityFails() {
        let item = makeItem(quantity: -1)
        #expect(item.validate().contains { $0.contains("Quantity") })
    }

    @Test func excessiveQuantityFails() {
        let item = makeItem(quantity: 1_000_001)
        #expect(item.validate().contains { $0.contains("Quantity") })
    }

    @Test func emptyCategoryFails() {
        let item = makeItem(category: "")
        #expect(item.validate().contains { $0.contains("Category") })
    }

    @Test func longCategoryFails() {
        let item = makeItem(category: String(repeating: "a", count: 41))
        #expect(item.validate().contains { $0.contains("Category") })
    }

    @Test func expiryTooFarFails() {
        let item = makeItem(expiryDate: Date.now.addingTimeInterval(6 * 365.25 * 24 * 60 * 60))
        #expect(item.validate().contains { $0.contains("Expiry") })
    }

    @Test func negativeCostFails() {
        let item = makeItem(costPerUnitMinor: -1)
        #expect(item.validate().contains { $0.contains("Cost") })
    }
}
