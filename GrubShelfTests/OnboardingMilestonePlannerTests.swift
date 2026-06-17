import Foundation
import Testing
@testable import GrubShelf

struct OnboardingMilestonePlannerTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func suggestsExpiryMilestoneAfterTwoDaysWithoutDates() throws {
        let firstUse = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23)))

        let pending = OnboardingMilestonePlanner.pendingMilestones(
            referenceDate: today,
            firstUseDate: firstUse,
            deliveredMilestones: [],
            pantryItemCount: 4,
            itemsWithExpiryCount: 1,
            shoppingItemCount: 2,
            calendar: calendar
        )

        #expect(pending.contains { $0.identifier == OnboardingMilestone.setExpiryDates.rawValue })
    }

    @Test func skipsDeliveredMilestones() throws {
        let firstUse = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 24)))

        let pending = OnboardingMilestonePlanner.pendingMilestones(
            referenceDate: today,
            firstUseDate: firstUse,
            deliveredMilestones: [OnboardingMilestone.createShoppingList.rawValue],
            pantryItemCount: 4,
            itemsWithExpiryCount: 4,
            shoppingItemCount: 0,
            calendar: calendar
        )

        #expect(pending.contains { $0.identifier == OnboardingMilestone.createShoppingList.rawValue } == false)
    }
}
