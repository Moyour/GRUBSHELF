import Foundation
import UserNotifications

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

    func scheduleExpiryAlerts(items: [PantryItem]) {
        let expiryEnabled = UserDefaults.standard.object(forKey: "expiryReminders") as? Bool ?? true
        guard expiryEnabled else { return }

        // Remove old expiry notifications
        center.removePendingNotificationRequests(withIdentifiers:
            items.map { "expiry-\($0.itemId.uuidString)" }
        )

        let expiringSoon = items.filter { $0.state == .expiringSoon }

        if expiringSoon.count > 3 {
            // Batch notification
            let content = UNMutableNotificationContent()
            content.title = "Items Expiring Soon"
            content.body = "\(expiringSoon.count) items are expiring within 3 days."
            content.sound = .default
            content.categoryIdentifier = "EXPIRY_ALERT"

            let trigger = nextMorningTrigger()
            let request = UNNotificationRequest(identifier: "expiry-batch", content: content, trigger: trigger)
            center.add(request)
        } else {
            for item in expiringSoon {
                let content = UNMutableNotificationContent()
                content.title = "Expiring Soon"
                content.body = "\(item.name) expires soon."
                content.sound = .default
                content.categoryIdentifier = "EXPIRY_ALERT"

                let trigger = nextMorningTrigger()
                let request = UNNotificationRequest(
                    identifier: "expiry-\(item.itemId.uuidString)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func scheduleLowStockAlerts(items: [PantryItem]) {
        let lowStockEnabled = UserDefaults.standard.object(forKey: "lowStockReminders") as? Bool ?? true
        guard lowStockEnabled else { return }

        let lowStock = items.filter { $0.state == .lowStock }

        for item in lowStock {
            let id = "lowstock-\(item.itemId.uuidString)"

            let content = UNMutableNotificationContent()
            content.title = "Low Stock"
            content.body = "\(item.name) is running low."
            content.sound = .default
            content.categoryIdentifier = "LOW_STOCK_ALERT"

            let trigger = nextMorningTrigger()
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Usage / Stale Item Reminders

    func scheduleUsageReminders(items: [PantryItem]) {
        let usageEnabled = UserDefaults.standard.object(forKey: "usageReminders") as? Bool ?? true
        guard usageEnabled else { return }

        // Frequency cap: max 2 per week, 48h gap between reminders
        let lastReminderDate = UserDefaults.standard.object(forKey: "lastUsageReminderDate") as? Date
        if let last = lastReminderDate {
            let hoursSinceLast = Date.now.timeIntervalSince(last) / 3600
            if hoursSinceLast < 48 { return }
        }

        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now
        let weeklyCount = UserDefaults.standard.integer(forKey: "usageReminderWeekCount")
        let weekKey = UserDefaults.standard.object(forKey: "usageReminderWeekStart") as? Date

        var currentWeekCount = weeklyCount
        if let ws = weekKey, ws < weekStart {
            currentWeekCount = 0
        }

        if currentWeekCount >= 2 { return }

        // Filter stale items with active reminder status
        let staleItems = items.filter { item in
            item.isStale &&
            item.reminderStatus == .active &&
            !item.archived
        }

        guard !staleItems.isEmpty else { return }

        // Remove old usage notifications
        center.removePendingNotificationRequests(withIdentifiers: ["usage-batch"])

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "USAGE_REMINDER"
        content.sound = .default

        if staleItems.count == 1, let item = staleItems.first {
            content.title = "Pantry Check-in"
            content.body = "Do you still have \(item.name)? It hasn't been updated in \(item.daysSinceLastUpdate) days."
        } else {
            content.title = "Pantry Review"
            content.body = "\(staleItems.count) items haven't been updated recently. Tap to review."
        }

        let trigger = nextMorningTrigger()
        let request = UNNotificationRequest(identifier: "usage-batch", content: content, trigger: trigger)
        center.add(request)

        // Update frequency tracking
        UserDefaults.standard.set(Date.now, forKey: "lastUsageReminderDate")
        UserDefaults.standard.set(currentWeekCount + 1, forKey: "usageReminderWeekCount")
        UserDefaults.standard.set(weekStart, forKey: "usageReminderWeekStart")
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func nextMorningTrigger() -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
