import Foundation
import UserNotifications

/// Budget state for notification priority.
struct NotificationBudgetState {
    let budgetRemainingMinor: Int
    let budgetAmountMinor: Int
    let budgetReminderEnabled: Bool
}

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // MARK: - Prioritized Alerts (unified flow)

    /// Schedules a single daily batched notification with priority-ordered content.
    func schedulePrioritizedAlerts(
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem],
        budgetState: NotificationBudgetState?
    ) {
        center.removeAllPendingNotificationRequests()

        let expiryEnabled = UserDefaults.standard.object(forKey: "expiryReminders") as? Bool ?? true
        let lowStockEnabled = UserDefaults.standard.object(forKey: "lowStockReminders") as? Bool ?? true
        let usageEnabled = UserDefaults.standard.object(forKey: "usageReminders") as? Bool ?? true

        let critical = expiryEnabled ? pantryItems.filter { item in
            guard let exp = item.expiryDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
            return days >= 0 && days <= 1
        } : []
        let highExpiry = expiryEnabled ? pantryItems.filter { item in
            item.state == .expiringSoon && !critical.contains(where: { $0.itemId == item.itemId })
        } : []
        let highLowStock = lowStockEnabled ? pantryItems.filter { $0.state == .lowStock } : []
        let mediumUsage = usageEnabled ? pantryItems.filter { item in
            item.isStale && item.reminderStatus == .active && !item.archived
        } : []

        var budgetLow = false
        if let budget = budgetState, budget.budgetReminderEnabled, budget.budgetAmountMinor > 0 {
            let remaining = Double(budget.budgetRemainingMinor) / Double(budget.budgetAmountMinor)
            budgetLow = remaining < 0.1 && remaining >= 0
        }

        let preferredWeekday = EngagementStore.shared.preferredShoppingWeekday()
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let shoppingReminder = !shoppingItems.isEmpty && preferredWeekday == todayWeekday

        var parts: [String] = []
        if !critical.isEmpty {
            parts.append("\(critical.count) item\(critical.count == 1 ? "" : "s") expiring today/tomorrow")
        }
        if !highExpiry.isEmpty {
            parts.append("\(highExpiry.count) expiring soon")
        }
        if !highLowStock.isEmpty {
            parts.append("\(highLowStock.count) low stock")
        }
        if budgetLow {
            parts.append("budget almost used")
        }
        if !mediumUsage.isEmpty {
            parts.append("\(mediumUsage.count) need review")
        }
        if shoppingReminder {
            parts.append("\(shoppingItems.count) on shopping list")
        }

        guard !parts.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Heads up"
        content.body = parts.joined(separator: ", ")
        content.sound = .default
        content.categoryIdentifier = "PANTRY_UPDATE"
        content.userInfo = ["source": "prioritized"]

        let hour = EngagementStore.shared.preferredNotificationHour()
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "pantry-update-batch", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Legacy (for backward compatibility)

    func scheduleExpiryAlerts(items: [PantryItem]) {
        schedulePrioritizedAlerts(pantryItems: items, shoppingItems: [], budgetState: nil)
    }

    func scheduleLowStockAlerts(items: [PantryItem]) {
        schedulePrioritizedAlerts(pantryItems: items, shoppingItems: [], budgetState: nil)
    }

    func scheduleUsageReminders(items: [PantryItem]) {
        let usageEnabled = UserDefaults.standard.object(forKey: "usageReminders") as? Bool ?? true
        guard usageEnabled else { return }

        let lastReminderDate = UserDefaults.standard.object(forKey: "lastUsageReminderDate") as? Date
        if let last = lastReminderDate {
            let hoursSinceLast = Date.now.timeIntervalSince(last) / 3600
            if hoursSinceLast < 48 { return }
        }

        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now
        var weeklyCount = UserDefaults.standard.integer(forKey: "usageReminderWeekCount")
        let weekKey = UserDefaults.standard.object(forKey: "usageReminderWeekStart") as? Date

        if let ws = weekKey, ws < weekStart {
            weeklyCount = 0
        }
        if weeklyCount >= 2 { return }

        let staleItems = items.filter { item in
            item.isStale && item.reminderStatus == .active && !item.archived
        }
        guard !staleItems.isEmpty else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["usage-batch"])

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "USAGE_REMINDER"
        content.sound = .default
        if staleItems.count == 1, let item = staleItems.first {
            content.title = "Still got \(item.name)?"
            content.body = "It hasn't been updated in \(item.daysSinceLastUpdate) days"
        } else {
            content.title = "Time for a review"
            content.body = "\(staleItems.count) items haven't been updated recently"
        }
        content.userInfo = ["category": "USAGE_REMINDER"]

        let hour = EngagementStore.shared.preferredNotificationHour()
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: "usage-batch", content: content, trigger: trigger))

        UserDefaults.standard.set(Date.now, forKey: "lastUsageReminderDate")
        UserDefaults.standard.set(weeklyCount + 1, forKey: "usageReminderWeekCount")
        UserDefaults.standard.set(weekStart, forKey: "usageReminderWeekStart")
    }

    // MARK: - Auto-Archive Warning

    /// Schedules a notification warning the user that items will be auto-archived soon.
    func scheduleAutoArchiveWarning(items: [PantryItem]) {
        guard !items.isEmpty else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["auto-archive-warning"])

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "AUTO_ARCHIVE_WARNING"
        content.sound = .default

        if items.count == 1, let item = items.first {
            content.title = "\(item.name) expired"
            content.body = "Use it today or bin it"
        } else {
            content.title = "\(items.count) items expired"
            content.body = "\(items.map(\.name).prefix(3).joined(separator: ", "))\(items.count > 3 ? " and \(items.count - 3) more" : "") — use them or clear them out"
        }
        content.userInfo = ["category": "AUTO_ARCHIVE_WARNING"]

        // Notify immediately (within a few seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        center.add(UNNotificationRequest(identifier: "auto-archive-warning", content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
