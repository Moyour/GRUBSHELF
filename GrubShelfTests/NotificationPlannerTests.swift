import Foundation
import Testing
@testable import GrubShelf

struct NotificationPlannerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func makeItem(
        name: String = "Milk",
        expiryDate: Date? = nil,
        quantity: Double = 2,
        lowStockThreshold: Double = 1,
        category: String = "Dairy",
        expectedUsageCycleDays: Int? = nil,
        lastQuantityUpdateDate: Date? = nil,
        reminderStatus: ReminderStatus = .active,
        archived: Bool = false
    ) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: name,
            quantity: quantity,
            unit: .l,
            category: category,
            expiryDate: expiryDate,
            lowStockThreshold: lowStockThreshold,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: archived,
            lastQuantityUpdateDate: lastQuantityUpdateDate,
            expectedUsageCycleDays: expectedUsageCycleDays,
            reminderStatus: reminderStatus
        )
    }

    private func referenceDate() throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 8)))
    }

    private func input(
        pantryItems: [PantryItem] = [],
        shoppingItemCount: Int = 0,
        openedAppAfterDigestHourToday: Bool = false,
        reviewedExpiringItemsToday: Bool = false,
        referenceDate: Date
    ) -> NotificationPlannerInput {
        NotificationPlannerInput(
            pantryItems: pantryItems,
            shoppingItemCount: shoppingItemCount,
            budgetRemainingMinor: nil,
            budgetAmountMinor: nil,
            budgetReminderEnabled: true,
            expiryEnabled: true,
            lowStockEnabled: true,
            usageEnabled: true,
            preferredShoppingWeekday: nil,
            todayWeekday: calendar.component(.weekday, from: referenceDate),
            referenceDate: referenceDate,
            calendar: calendar,
            preferredHour: 9,
            openedAppAfterDigestHourToday: openedAppAfterDigestHourToday,
            reviewedExpiringItemsToday: reviewedExpiringItemsToday
        )
    }

    @Test func immediateAlertForSingleItemExpiringToday() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25)))
        let item = makeItem(name: "Spinach", expiryDate: expiry)
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )

        let urgent = planned.filter { $0.categoryIdentifier == "EXPIRY_URGENT" }
        #expect(urgent.count == 1)
        #expect(urgent[0].title == "Spinach expires today")
        #expect(urgent[0].destination == .pantryExpiring)
    }

    @Test func dailyDigestBriefingFormatWithExpiring() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 2, to: today))
        let item = makeItem(name: "Yogurt", expiryDate: expiry)
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )

        let digest = try #require(planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier })
        #expect(digest.title == "Your kitchen today")
        #expect(digest.body.contains("Yogurt expires in 2 days"))
        #expect(digest.body.contains("1 item tracked."))
        #expect(digest.destination == .pantryExpiring)
    }

    @Test func skipsDailyDigestWhenUserAlreadyOpenedAfterDigestHour() throws {
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10)))
        let expiry = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 27)))
        let item = makeItem(name: "Yogurt", expiryDate: expiry)
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], openedAppAfterDigestHourToday: true, referenceDate: today)
        )

        #expect(planned.contains { $0.identifier == NotificationPlanner.dailyDigestIdentifier } == false)
    }

    @Test func lowStockDigestBriefingFormat() throws {
        let today = try referenceDate()
        let item = makeItem(name: "Rice", quantity: 0.5, lowStockThreshold: 2)
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )

        let digest = try #require(planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier })
        #expect(digest.title == "Your kitchen today")
        #expect(digest.body.contains("1 running low."))
        #expect(digest.destination == .pantryLowStock)
    }

    @Test func digestReturnsNilWhenZeroItemsTracked() throws {
        let today = try referenceDate()
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest == nil)
    }

    @Test func digestShowsAllGoodWhenNothingUrgent() throws {
        let today = try referenceDate()
        // Item with no expiry date and not low stock — nothing actionable
        let item = makeItem(name: "Salt", quantity: 5, lowStockThreshold: 1)
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = try #require(planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier })
        #expect(digest.title == "Your kitchen looks good")
        #expect(digest.body.contains("1 item tracked"))
    }

    @Test func preservesPendingDigestWhenStillBeforePreferredHour() throws {
        let today = try referenceDate()
        let pending = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 9)))
        let shouldPreserve = NotificationPlanner.shouldPreservePendingDigest(
            pendingFireDate: pending,
            referenceDate: today,
            preferredHour: 9,
            calendar: calendar
        )
        #expect(shouldPreserve == true)
    }

    // MARK: - Category-aware expiry lead times

    @Test func dairyItemFourDaysOutTriggersAlert() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 4, to: today))
        let item = makeItem(name: "Milk", expiryDate: expiry, category: "Dairy")
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest != nil, "Dairy item expiring in 4 days should appear in digest")
    }

    @Test func cannedItemEightDaysOutDoesNotTriggerAlert() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 8, to: today))
        let item = makeItem(name: "Beans", expiryDate: expiry, category: "Canned")
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest == nil, "Canned item expiring in 8 days should NOT appear in digest (lead is 7)")
    }

    @Test func seafoodItemTwoDaysOutTriggersAlert() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 2, to: today))
        let item = makeItem(name: "Salmon", expiryDate: expiry, category: "Seafood")
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest != nil, "Seafood item expiring in 2 days should appear in digest")
    }

    @Test func seafoodItemThreeDaysOutDoesNotTriggerAlert() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 3, to: today))
        let item = makeItem(name: "Shrimp", expiryDate: expiry, category: "Seafood")
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest == nil, "Seafood item expiring in 3 days should NOT appear in digest (lead is 2)")
    }

    @Test func frozenItemSevenDaysOutTriggersAlert() throws {
        let today = try referenceDate()
        let expiry = try #require(calendar.date(byAdding: .day, value: 7, to: today))
        let item = makeItem(name: "Ice Cream", expiryDate: expiry, category: "Frozen")
        let planned = NotificationPlanner.plannedNotifications(
            input: input(pantryItems: [item], referenceDate: today)
        )
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        #expect(digest != nil, "Frozen item expiring in 7 days should appear in digest")
    }
}
