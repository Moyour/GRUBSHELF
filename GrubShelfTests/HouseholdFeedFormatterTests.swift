import Foundation
import Testing
@testable import GrubShelf

struct HouseholdFeedFormatterTests {
    private let cal = Calendar(identifier: .gregorian)

    // MARK: - Expiry

    @Test func expiryLineTomorrow() throws {
        let today = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10)))
        let expiry = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 11)))
        let item = PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: "Milk",
            quantity: 1,
            unit: .pcs,
            category: "Dairy",
            expiryDate: expiry,
            costPerUnitMinor: 100,
            lowStockThreshold: 0,
            createdBy: UUID(),
            createdAt: today,
            updatedAt: today,
            archived: false
        )
        let line = HouseholdFeedFormatter.expiryLine(for: item, referenceDate: today, calendar: cal)
        #expect(line == "expires tomorrow")
    }

    @Test func expiryLineExpired() throws {
        let today = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10)))
        let expiry = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 8)))
        let item = PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: "Milk",
            quantity: 1,
            unit: .pcs,
            category: "Dairy",
            expiryDate: expiry,
            lowStockThreshold: 0,
            createdBy: UUID(),
            createdAt: today,
            updatedAt: today,
            archived: false
        )
        let line = HouseholdFeedFormatter.expiryLine(for: item, referenceDate: today, calendar: cal)
        #expect(line == "expired")
    }

    // MARK: - Recency

    @Test func recencyHoursAgo() throws {
        let ref = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 14, minute: 0)))
        let past = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 12, minute: 0)))
        let label = HouseholdFeedFormatter.recencyLabel(for: past, referenceDate: ref, calendar: cal)
        #expect(label == "2h ago")
    }

    // MARK: - Budget

    @Test func budgetStatusOnTrack() {
        let headline = HouseholdFeedFormatter.budgetStatusHeadline(
            spendProgress: 0.5,
            budgetRemainingMinor: 5000,
            budgetAmountMinor: 10_000
        )
        #expect(headline == "On track")
    }

    @Test func budgetStatusOver() {
        let headline = HouseholdFeedFormatter.budgetStatusHeadline(
            spendProgress: 1.1,
            budgetRemainingMinor: -100,
            budgetAmountMinor: 10_000
        )
        #expect(headline == "Over budget")
    }

    @Test func daysRemainingMonthlyInclusive() throws {
        let settings = FinanceSettings(
            userId: UUID(),
            budgetPeriod: .monthly,
            budgetAmountMinor: 10_000,
            periodStartDay: 1,
            currency: "GBP"
        )
        let midMonth = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10)))
        let days = HouseholdFeedFormatter.daysRemainingInBudgetPeriod(settings: settings, now: midMonth, calendar: cal)
        #expect(days >= 1 && days <= 22)
    }

    // MARK: - Display names

    @Test func displayNameYou() {
        let uid = UUID()
        let name = HouseholdFeedFormatter.displayName(for: uid, members: [], currentUserId: uid)
        #expect(name == "You")
    }

    @Test func displayNameFirstName() {
        let uid = UUID()
        let member = AppUser(
            userId: uid,
            name: "Jane Doe",
            email: "j@example.com",
            householdId: UUID(),
            role: .member,
            createdAt: .now,
            updatedAt: .now
        )
        let name = HouseholdFeedFormatter.displayName(for: uid, members: [member], currentUserId: UUID())
        #expect(name == "Jane")
    }

    // MARK: - Compact list

    @Test func compactItemListTruncates() {
        let long = String(repeating: "a", count: 90)
        let out = HouseholdFeedFormatter.compactItemList([long], maxLength: 20)
        #expect(out.hasSuffix("…"))
        #expect(out.count <= 20)
    }

    @Test func sameDayShoppingHint() throws {
        let day = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 10, minute: 0)))
        let item = PantryItem(
            itemId: UUID(),
            householdId: UUID(),
            name: "Pasta",
            quantity: 1,
            unit: .pcs,
            category: "Grains",
            lowStockThreshold: 0,
            createdBy: UUID(),
            createdAt: day,
            updatedAt: day,
            archived: false
        )
        let trip = ShoppingTrip(
            tripId: UUID(),
            householdId: UUID(),
            shoppingListId: nil,
            date: day,
            totalCostMinor: 5000,
            itemCount: 4,
            period: "2026-W15",
            costLogged: true
        )
        let hint = HouseholdFeedFormatter.sameDayShoppingHint(items: [item], trips: [trip], calendar: cal)
        #expect(hint != nil)
    }

    // MARK: - Today queue

    @Test func todayQueuePrioritizesExpiryThenLowStock() {
        let input = TodayQueuePlanner.Input(
            expiringCount: 2,
            lowStockCount: 1,
            shoppingTotal: 0,
            shoppingCompleted: 0,
            hasBudget: false,
            staleCount: 0
        )
        let slots = TodayQueuePlanner.prioritizedSlots(input: input)
        #expect(slots == [.expiringSoon, .lowStock])
    }

    @Test func todayQueueIncludesShoppingWhenIncomplete() {
        let input = TodayQueuePlanner.Input(
            expiringCount: 0,
            lowStockCount: 0,
            shoppingTotal: 5,
            shoppingCompleted: 2,
            hasBudget: true,
            staleCount: 0
        )
        let slots = TodayQueuePlanner.prioritizedSlots(input: input)
        #expect(slots == [.shopping, .budget])
    }

    @Test func todayQueueOmitsShoppingWhenComplete() {
        let input = TodayQueuePlanner.Input(
            expiringCount: 0,
            lowStockCount: 0,
            shoppingTotal: 3,
            shoppingCompleted: 3,
            hasBudget: false,
            staleCount: 1
        )
        let slots = TodayQueuePlanner.prioritizedSlots(input: input)
        #expect(slots == [.staleReview])
    }

    @Test func todayQueueCapsAtFive() {
        let input = TodayQueuePlanner.Input(
            expiringCount: 1,
            lowStockCount: 1,
            shoppingTotal: 4,
            shoppingCompleted: 0,
            hasBudget: true,
            staleCount: 9
        )
        let slots = TodayQueuePlanner.prioritizedSlots(input: input, maxCount: 5)
        #expect(slots.count == 5)
        #expect(slots == [.expiringSoon, .lowStock, .shopping, .budget, .staleReview])
    }

    @Test func todayQueueEmptyWhenNothingApplies() {
        let input = TodayQueuePlanner.Input(
            expiringCount: 0,
            lowStockCount: 0,
            shoppingTotal: 0,
            shoppingCompleted: 0,
            hasBudget: false,
            staleCount: 0
        )
        #expect(TodayQueuePlanner.prioritizedSlots(input: input).isEmpty)
    }

    @Test func feedLastUpdatedLabelContainsUpdated() throws {
        let now = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 12, minute: 0)))
        let past = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 11, minute: 30)))
        let label = FeedSyncFormatter.lastUpdatedLabel(at: past, now: now)
        #expect(label.hasPrefix("Updated "))
        #expect(label.count > 8)
    }
}
