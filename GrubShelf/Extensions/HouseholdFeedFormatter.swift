import Foundation

/// Pure formatting for the Home “Feed” — testable without SwiftUI.
enum HouseholdFeedFormatter {
    // MARK: - Expiry & value

    static func expiryLine(
        for item: PantryItem,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        guard let expiry = item.expiryDate else { return "is due soon" }
        let today = calendar.startOfDay(for: referenceDate)
        let expDay = calendar.startOfDay(for: expiry)
        let days = calendar.dateComponents([.day], from: today, to: expDay).day ?? 0
        if days < 0 { return "expired" }
        if days == 0 { return "expires today" }
        if days == 1 { return "expires tomorrow" }
        return "expires in \(days) days"
    }

    static func estimatedWorth(for item: PantryItem, currencyCode: String) -> String {
        let minor = Int(item.quantity * Double(item.costPerUnitMinor ?? 120))
        return minor.currencyFormatted(currencyCode: currencyCode)
    }

    // MARK: - Recency

    static func recencyLabel(
        for date: Date,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if referenceDate < date { return "just now" }
        let hours = calendar.dateComponents([.hour], from: date, to: referenceDate).hour ?? 0
        if hours < 1 { return "just now" }
        if hours < 24 { return "\(hours)h ago" }
        let days = max(1, hours / 24)
        return "\(days)d ago"
    }

    // MARK: - Budget

    static func budgetStatusHeadline(spendProgress: Double, budgetRemainingMinor: Int, budgetAmountMinor: Int) -> String {
        if budgetAmountMinor <= 0 { return "Budget" }
        if budgetRemainingMinor < 0 { return "Over budget" }
        let remainingFraction = Double(budgetRemainingMinor) / Double(budgetAmountMinor)
        if spendProgress <= 0.62 && remainingFraction >= 0.2 { return "On track" }
        if spendProgress <= 0.88 { return "Watch spending" }
        return "Almost at cap"
    }

    static func daysRemainingInBudgetPeriod(
        settings: FinanceSettings?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard let settings else { return 1 }
        switch settings.budgetPeriod {
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 1 }
            let lastMoment = interval.end.addingTimeInterval(-1)
            return inclusiveDaysFromToday(to: lastMoment, now: now, calendar: calendar)
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return 1 }
            let lastMoment = interval.end.addingTimeInterval(-1)
            return inclusiveDaysFromToday(to: lastMoment, now: now, calendar: calendar)
        }
    }

    private static func inclusiveDaysFromToday(to endDate: Date, now: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: now)
        let endDay = calendar.startOfDay(for: endDate)
        let d = calendar.dateComponents([.day], from: today, to: endDay).day ?? 0
        return max(1, d + 1)
    }

    static func budgetSpentRemainingLine(
        spentMinor: Int,
        remainingMinor: Int,
        currencyCode: String,
        period: BudgetPeriod?
    ) -> String {
        let spent = spentMinor.currencyFormatted(currencyCode: currencyCode)
        let remaining = max(0, remainingMinor).currencyFormatted(currencyCode: currencyCode)
        switch period {
        case .weekly:
            return "\(spent) spent — \(remaining) left this week"
        case .monthly:
            return "\(spent) spent — \(remaining) left this month"
        case .none:
            return "\(spent) spent — \(remaining) left"
        }
    }

    // MARK: - Additions (member-aware)

    static func additionsTitle(items: [PantryItem], members: [AppUser], currentUserId: UUID) -> String {
        guard !items.isEmpty else { return "No household updates yet" }
        let creatorIds = Set(items.map(\.createdBy))
        if creatorIds.count == 1, let only = creatorIds.first {
            let display = displayName(for: only, members: members, currentUserId: currentUserId)
            return "\(display) added \(items.count) item\(items.count == 1 ? "" : "s")"
        }
        return "Household added \(items.count) item\(items.count == 1 ? "" : "s")"
    }

    static func displayName(for userId: UUID, members: [AppUser], currentUserId: UUID) -> String {
        if userId == currentUserId { return "You" }
        if let match = members.first(where: { $0.userId == userId }) {
            let trimmed = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = trimmed.split(separator: " ").first, !first.isEmpty {
                return String(first)
            }
            if !trimmed.isEmpty { return trimmed }
        }
        return "Someone"
    }

    /// Joins item names for a subtitle; truncates with an ellipsis when too long.
    static func compactItemList(_ names: [String], maxLength: Int = 72) -> String {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return "" }
        var result = cleaned[0]
        if result.count > maxLength {
            let idx = result.index(result.startIndex, offsetBy: max(0, maxLength - 1))
            return String(result[..<idx]) + "…"
        }
        for i in 1..<cleaned.count {
            let candidate = result + ", " + cleaned[i]
            if candidate.count > maxLength - 1 {
                return result + "…"
            }
            result = candidate
        }
        return result
    }

    // MARK: - Shopping context (no store field on trips — same-day hint only)

    static func sameDayShoppingHint(items: [PantryItem], trips: [ShoppingTrip], calendar: Calendar = .current) -> String? {
        guard let newest = items.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
        let day = calendar.startOfDay(for: newest.createdAt)
        let hasTripSameDay = trips.contains { calendar.startOfDay(for: $0.date) == day }
        return hasTripSameDay ? "Same day as a logged shop" : nil
    }
}

// MARK: - Today queue (Home “actions first”)

/// Ordered slots for the Home “Today’s actions” card. Pure logic for tests and UI.
enum TodayQueueSlot: String, CaseIterable, Equatable, Sendable {
    case expiringSoon
    case lowStock
    case shopping
    case budget
    case staleReview
}

/// Short label for “last refreshed” on the Home Feed (testable).
enum FeedSyncFormatter {
    static func lastUpdatedLabel(at date: Date, now: Date = .now) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "Updated \(f.localizedString(for: date, relativeTo: now))"
    }
}

enum TodayQueuePlanner {
    struct Input: Equatable, Sendable {
        var expiringCount: Int
        var lowStockCount: Int
        var shoppingTotal: Int
        var shoppingCompleted: Int
        var hasBudget: Bool
        var staleCount: Int
    }

    /// Priority: expiring → low stock → incomplete shopping → budget (when set) → stale review. At most `maxCount` slots.
    static func prioritizedSlots(input: Input, maxCount: Int = 5) -> [TodayQueueSlot] {
        var slots: [TodayQueueSlot] = []
        if input.expiringCount > 0 { slots.append(.expiringSoon) }
        if input.lowStockCount > 0 { slots.append(.lowStock) }
        if input.shoppingTotal > 0, input.shoppingCompleted < input.shoppingTotal {
            slots.append(.shopping)
        }
        if input.hasBudget { slots.append(.budget) }
        if input.staleCount > 0 { slots.append(.staleReview) }
        return Array(slots.prefix(maxCount))
    }
}
