import Foundation

enum NotificationDestination: String, Equatable {
    case pantryExpiring = "pantry_expiring"
    case pantryLowStock = "pantry_low_stock"
    case pantryReview = "pantry_review"
    case shop = "shop"
    case approvals = "approvals"
}

struct PlannedNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let categoryIdentifier: String
    let destination: NotificationDestination?
    /// When set, fire soon after scheduling instead of at the daily digest hour.
    let fireAfterSeconds: TimeInterval?
}

struct NotificationPlannerInput: Equatable {
    let pantryItems: [PantryItem]
    let shoppingItemCount: Int
    let budgetRemainingMinor: Int?
    let budgetAmountMinor: Int?
    let budgetReminderEnabled: Bool
    let expiryEnabled: Bool
    let lowStockEnabled: Bool
    let usageEnabled: Bool
    let preferredShoppingWeekday: Int?
    let todayWeekday: Int
    let referenceDate: Date
    let calendar: Calendar
    let preferredHour: Int
    let openedAppAfterDigestHourToday: Bool
    let reviewedExpiringItemsToday: Bool
}

enum NotificationPlanner {
    static let dailyDigestIdentifier = "pantry-update-batch"

    static func plannedNotifications(input: NotificationPlannerInput) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []
        planned.append(contentsOf: immediateExpiryAlerts(input: input))
        if let digest = dailyDigest(input: input), !shouldSkipDailyDigest(input: input) {
            planned.append(digest)
        }
        return planned
    }

    static func shouldSkipDailyDigest(input: NotificationPlannerInput) -> Bool {
        input.openedAppAfterDigestHourToday || input.reviewedExpiringItemsToday
    }

    static func shouldPreservePendingDigest(
        pendingFireDate: Date?,
        referenceDate: Date,
        preferredHour: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard let pendingFireDate else { return false }
        guard pendingFireDate > referenceDate else { return false }
        let today = calendar.startOfDay(for: referenceDate)
        let fireDay = calendar.startOfDay(for: pendingFireDate)
        guard fireDay == today else { return false }
        let hour = calendar.component(.hour, from: referenceDate)
        return hour < preferredHour
    }

    static func immediateExpiryAlerts(input: NotificationPlannerInput) -> [PlannedNotification] {
        guard input.expiryEnabled else { return [] }

        let expiringToday = actionablePantryItems(from: input.pantryItems).filter { item in
            guard let expiry = item.expiryDate else { return false }
            let today = input.calendar.startOfDay(for: input.referenceDate)
            let expDay = input.calendar.startOfDay(for: expiry)
            return expDay == today
        }
        .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }

        guard !expiringToday.isEmpty else { return [] }

        if expiringToday.count == 1, let item = expiringToday.first {
            return [
                PlannedNotification(
                    identifier: "expiry-urgent-\(item.itemId.uuidString)",
                    title: "\(item.name) expires today",
                    body: "Use it today or add it to your shopping list.",
                    categoryIdentifier: "EXPIRY_URGENT",
                    destination: .pantryExpiring,
                    fireAfterSeconds: 3
                )
            ]
        }

        let names = expiringToday.prefix(2).map(\.name).joined(separator: ", ")
        let suffix = expiringToday.count > 2 ? " and \(expiringToday.count - 2) more" : ""
        return [
            PlannedNotification(
                identifier: "expiry-urgent-batch",
                title: "\(expiringToday.count) items expire today",
                body: "\(names)\(suffix)",
                categoryIdentifier: "EXPIRY_URGENT",
                destination: .pantryExpiring,
                fireAfterSeconds: 3
            )
        ]
    }

    static func dailyDigest(input: NotificationPlannerInput) -> PlannedNotification? {
        let actionable = actionablePantryItems(from: input.pantryItems)
        let totalCount = actionable.count

        // Don't send if zero items tracked — avoids reminding inactive users.
        guard totalCount > 0 else { return nil }

        let expiring = expiringSoonItems(input: input)
        let lowStock = input.lowStockEnabled
            ? actionable.filter { $0.state == .lowStock }
            : []
        let shoppingReminder = input.shoppingItemCount > 0
            && input.preferredShoppingWeekday == input.todayWeekday

        let hasUrgentContent = !expiring.isEmpty || !lowStock.isEmpty || shoppingReminder

        guard hasUrgentContent else {
            // Nothing urgent — send a reassuring "all good" briefing.
            return PlannedNotification(
                identifier: dailyDigestIdentifier,
                title: "Your kitchen looks good",
                body: "\(totalCount) item\(totalCount == 1 ? "" : "s") tracked, nothing expiring soon.",
                categoryIdentifier: "PANTRY_UPDATE",
                destination: nil,
                fireAfterSeconds: nil
            )
        }

        // Build briefing-style body: "12 items tracked. Milk expires tomorrow. 3 running low."
        var bodyParts: [String] = []
        bodyParts.append("\(totalCount) item\(totalCount == 1 ? "" : "s") tracked.")

        // Lead with the most urgent expiry
        let destination: NotificationDestination
        if !expiring.isEmpty {
            let expirySnippets = expiring.prefix(2).map { item in
                let line = HouseholdFeedFormatter.expiryLine(
                    for: item,
                    referenceDate: input.referenceDate,
                    calendar: input.calendar
                )
                return "\(item.name) \(line)"
            }
            bodyParts.append(expirySnippets.joined(separator: ", ") + ".")
            destination = .pantryExpiring
        } else {
            destination = lowStock.isEmpty ? .shop : .pantryLowStock
        }

        // Mention low-stock count
        if !lowStock.isEmpty {
            bodyParts.append("\(lowStock.count) running low.")
        }

        // Mention shopping reminder
        if shoppingReminder {
            bodyParts.append("\(input.shoppingItemCount) on your list.")
        }

        let body = bodyParts.joined(separator: " ")

        return PlannedNotification(
            identifier: dailyDigestIdentifier,
            title: "Your kitchen today",
            body: body,
            categoryIdentifier: "PANTRY_UPDATE",
            destination: destination,
            fireAfterSeconds: nil
        )
    }

    private static func expiringSoonItems(input: NotificationPlannerInput) -> [PantryItem] {
        guard input.expiryEnabled else { return [] }
        return actionablePantryItems(from: input.pantryItems)
            .filter { item in
                guard let days = daysUntilExpiry(item, input: input) else { return false }
                let lead = PantryItem.expiryAlertLeadDays(for: item.category)
                return days >= 0 && days <= lead
            }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private static func isCriticalExpiry(_ item: PantryItem, input: NotificationPlannerInput) -> Bool {
        guard let days = daysUntilExpiry(item, input: input) else { return false }
        return (0...1).contains(days)
    }

    /// Calendar days from `referenceDate` to expiry (nil if no expiry).
    private static func daysUntilExpiry(_ item: PantryItem, input: NotificationPlannerInput) -> Int? {
        guard let expiry = item.expiryDate else { return nil }
        let today = input.calendar.startOfDay(for: input.referenceDate)
        let expDay = input.calendar.startOfDay(for: expiry)
        return input.calendar.dateComponents([.day], from: today, to: expDay).day
    }

    private static func budgetIsLow(input: NotificationPlannerInput) -> Bool {
        guard input.budgetReminderEnabled,
              let remaining = input.budgetRemainingMinor,
              let total = input.budgetAmountMinor,
              total > 0 else { return false }
        let fraction = Double(remaining) / Double(total)
        return fraction < 0.1 && fraction >= 0
    }

    private static func actionablePantryItems(from items: [PantryItem]) -> [PantryItem] {
        items.filter { !$0.archived && $0.approvalStatus == .approved }
    }
}
