import Foundation

/// Persists engagement data for adaptive notification timing.
final class EngagementStore {
    static let shared = EngagementStore()

    private let defaults = UserDefaults.standard
    private let appOpenKey = "engagement_appOpenDates"
    private let notificationTapKey = "engagement_notificationTapDates"
    private let shoppingActionKey = "engagement_shoppingActionDates"
    private let expiringReviewKey = "engagement_lastExpiringReviewAt"
    private let maxStored = 100
    private let defaultHour = 9

    private init() {}

    func recordAppOpen() {
        appendDate(to: appOpenKey)
    }

    func recordNotificationTap(category: String) {
        appendDate(to: notificationTapKey)
    }

    func recordShoppingAction() {
        appendDate(to: shoppingActionKey)
    }

    func recordExpiringItemsReview(referenceDate: Date = .now) {
        defaults.set(referenceDate.timeIntervalSince1970, forKey: expiringReviewKey)
    }

    func reviewedExpiringItemsToday(referenceDate: Date = .now, calendar: Calendar = .current) -> Bool {
        let timestamp = defaults.double(forKey: expiringReviewKey)
        guard timestamp > 0 else { return false }
        let reviewedAt = Date(timeIntervalSince1970: timestamp)
        return calendar.startOfDay(for: reviewedAt) == calendar.startOfDay(for: referenceDate)
    }

    /// Returns hour (0–23) with highest engagement in last 7–14 days. Fallback: 9.
    func preferredNotificationHour() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let cutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let opens = loadDates(forKey: appOpenKey).filter { $0 >= cutoff }
        let taps = loadDates(forKey: notificationTapKey).filter { $0 >= cutoff }
        let combined = (opens + taps).sorted()

        guard !combined.isEmpty else { return defaultHour }

        var hourCounts = [Int: Int]()

        for date in combined {
            let hour = calendar.component(.hour, from: date)
            hourCounts[hour, default: 0] += 1
        }

        let best = hourCounts.max(by: { $0.value < $1.value })
        return best?.key ?? defaultHour
    }

    /// True when the user already opened the app today at or after the preferred digest hour.
    func openedAppAfterNotificationHour(preferredHour: Int, referenceDate: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let lastOpen = loadDates(forKey: appOpenKey).last else { return false }
        let today = calendar.startOfDay(for: referenceDate)
        guard calendar.startOfDay(for: lastOpen) == today else { return false }
        return calendar.component(.hour, from: lastOpen) >= preferredHour
    }

    /// Returns weekday (1=Sunday … 7=Saturday) with most shopping actions in last 4 weeks, or nil if insufficient data.
    func preferredShoppingWeekday() -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let cutoff = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        let actions = loadDates(forKey: shoppingActionKey).filter { $0 >= cutoff }
        guard actions.count >= 2 else { return nil }

        var weekdayCounts = [Int: Int]()
        for date in actions {
            let weekday = calendar.component(.weekday, from: date)
            weekdayCounts[weekday, default: 0] += 1
        }

        return weekdayCounts.max(by: { $0.value < $1.value })?.key
    }

    /// Number of distinct calendar days the user has opened the app.
    func distinctActiveDays(calendar: Calendar = .current) -> Int {
        let dates = loadDates(forKey: appOpenKey)
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.count
    }

    private func appendDate(to key: String) {
        var dates = loadDates(forKey: key)
        dates.append(Date())
        if dates.count > maxStored {
            dates = Array(dates.suffix(maxStored))
        }
        saveDates(dates, forKey: key)
    }

    private func loadDates(forKey key: String) -> [Date] {
        (defaults.array(forKey: key) as? [TimeInterval] ?? [])
            .map { Date(timeIntervalSince1970: $0) }
    }

    private func saveDates(_ dates: [Date], forKey key: String) {
        defaults.set(dates.map(\.timeIntervalSince1970), forKey: key)
    }
}
