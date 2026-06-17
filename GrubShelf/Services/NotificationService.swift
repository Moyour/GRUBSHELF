import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let openPendingApprovals = Notification.Name("GrubShelf.openPendingApprovals")
    static let openPantryExpiring = Notification.Name("GrubShelf.openPantryExpiring")
    static let openPantryLowStock = Notification.Name("GrubShelf.openPantryLowStock")
    static let openPantryReview = Notification.Name("GrubShelf.openPantryReview")
    static let openShoppingTab = Notification.Name("GrubShelf.openShoppingTab")
}

/// Identifies pending items that haven't triggered an admin alert yet.
enum ApprovalNotificationTracker {
    static func newlyPendingItems(
        knownPendingIDs: Set<UUID>,
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem]
    ) -> [PendingApprovalAlert] {
        var alerts: [PendingApprovalAlert] = []
        for item in pantryItems where item.approvalStatus == .pending && !knownPendingIDs.contains(item.itemId) {
            alerts.append(PendingApprovalAlert(itemId: item.itemId, itemName: item.name, itemType: "pantry"))
        }
        for item in shoppingItems where item.approvalStatus == .pending && !knownPendingIDs.contains(item.itemId) {
            alerts.append(PendingApprovalAlert(itemId: item.itemId, itemName: item.name, itemType: "shopping"))
        }
        return alerts
    }

    static func pendingItemIDs(pantryItems: [PantryItem], shoppingItems: [ShoppingItem]) -> Set<UUID> {
        let pantry = pantryItems.filter { $0.approvalStatus == .pending }.map(\.itemId)
        let shopping = shoppingItems.filter { $0.approvalStatus == .pending }.map(\.itemId)
        return Set(pantry + shopping)
    }
}

struct PendingApprovalAlert: Equatable, Sendable {
    let itemId: UUID
    let itemName: String
    let itemType: String
}

/// Delivers local alerts when members submit items for admin approval.
@MainActor
final class ApprovalNotificationCoordinator {
    static let shared = ApprovalNotificationCoordinator()

    private let deliveredIDsKey = "deliveredApprovalNotificationIds_v2"
    private var deliveredNotificationIDs: Set<UUID> = []
    /// In-memory dedupe within a single app session (avoids duplicate alerts on rapid refreshes).
    private var sessionPendingIDs: Set<UUID> = []

    private init() {
        if let stored = UserDefaults.standard.array(forKey: deliveredIDsKey) as? [String] {
            deliveredNotificationIDs = Set(stored.compactMap(UUID.init(uuidString:)))
        }
    }

    func resetSession() {
        sessionPendingIDs.removeAll()
    }

    func processPendingItems(
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem],
        isAdmin: Bool
    ) {
        guard isAdmin else { return }

        let currentPending = ApprovalNotificationTracker.pendingItemIDs(
            pantryItems: pantryItems,
            shoppingItems: shoppingItems
        )
        let skipIDs = deliveredNotificationIDs.union(sessionPendingIDs)
        let newAlerts = ApprovalNotificationTracker.newlyPendingItems(
            knownPendingIDs: skipIDs,
            pantryItems: pantryItems,
            shoppingItems: shoppingItems
        )

        sessionPendingIDs.formUnion(currentPending)

        guard !newAlerts.isEmpty else { return }

        Task {
            let authorized = await NotificationService.shared.ensureAuthorizationForAlerts()
            for alert in newAlerts {
                guard !deliveredNotificationIDs.contains(alert.itemId) else { continue }
                if authorized {
                    let delivered = await NotificationService.shared.deliverApprovalRequest(alert)
                    if delivered {
                        markDelivered(alert.itemId)
                    }
                }
            }
        }
    }

    func markDelivered(_ itemId: UUID) {
        deliveredNotificationIDs.insert(itemId)
        persistDeliveredIDs()
    }

    func clearDelivered(_ itemId: UUID) {
        deliveredNotificationIDs.remove(itemId)
        persistDeliveredIDs()
    }

    private func persistDeliveredIDs() {
        UserDefaults.standard.set(deliveredNotificationIDs.map(\.uuidString), forKey: deliveredIDsKey)
    }

    /// Backward-compatible hooks used by approval actions.
    func markNotified(_ itemId: UUID) { markDelivered(itemId) }
    func clearNotified(_ itemId: UUID) { clearDelivered(itemId) }
}

/// Budget state for notification priority.
struct NotificationBudgetState {
    let budgetRemainingMinor: Int
    let budgetAmountMinor: Int
    let budgetReminderEnabled: Bool
}

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private static let primerShownKey = "notificationPrimerShown"
    private static let promptShownKey = "notificationPromptShown"
    private static let urgentExpiryDeliveredKey = "urgentExpiryDeliveredDayKeys"

    var needsPermissionPrimer: Bool {
        !UserDefaults.standard.bool(forKey: Self.primerShownKey)
            && !UserDefaults.standard.bool(forKey: Self.promptShownKey)
    }

    func markPermissionPrimerShown() {
        UserDefaults.standard.set(true, forKey: Self.primerShownKey)
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Ensures the user can receive lock-screen / banner alerts. Prompts on first use.
    func ensureAuthorizationForAlerts() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestPermission()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Asks for notification permission once per install, after the user has seen value
    /// (first pantry add or post-onboarding). Skips if already prompted or already decided.
    func requestPermissionIfFirstTime() async {
        guard !UserDefaults.standard.bool(forKey: Self.promptShownKey) else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            UserDefaults.standard.set(true, forKey: Self.promptShownKey)
            UserDefaults.standard.set(true, forKey: Self.primerShownKey)
            return
        }
    }

    func requestPermissionAfterPrimer(application: UIApplication) async {
        markPermissionPrimerShown()
        UserDefaults.standard.set(true, forKey: Self.promptShownKey)
        _ = await requestPermission()
        await PushNotificationService.shared.registerIfAuthorized(application: application)
    }

    // MARK: - Unified scheduling

    /// Schedules the daily digest and any urgent same-day expiry alerts.
    func scheduleAll(
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem],
        budgetState: NotificationBudgetState?
    ) async {
        let preferredHour = EngagementStore.shared.preferredNotificationHour()
        let calendar = Calendar.current
        let now = Date()
        let input = NotificationPlannerInput(
            pantryItems: pantryItems,
            shoppingItemCount: shoppingItems.filter { !$0.completed }.count,
            budgetRemainingMinor: budgetState?.budgetRemainingMinor,
            budgetAmountMinor: budgetState?.budgetAmountMinor,
            budgetReminderEnabled: budgetState?.budgetReminderEnabled ?? true,
            expiryEnabled: UserDefaults.standard.object(forKey: "expiryReminders") as? Bool ?? true,
            lowStockEnabled: UserDefaults.standard.object(forKey: "lowStockReminders") as? Bool ?? true,
            usageEnabled: UserDefaults.standard.object(forKey: "usageReminders") as? Bool ?? true,
            preferredShoppingWeekday: EngagementStore.shared.preferredShoppingWeekday(),
            todayWeekday: calendar.component(.weekday, from: now),
            referenceDate: now,
            calendar: calendar,
            preferredHour: preferredHour,
            openedAppAfterDigestHourToday: EngagementStore.shared.openedAppAfterNotificationHour(
                preferredHour: preferredHour,
                referenceDate: now,
                calendar: calendar
            ),
            reviewedExpiringItemsToday: EngagementStore.shared.reviewedExpiringItemsToday(
                referenceDate: now,
                calendar: calendar
            )
        )

        let planned = NotificationPlanner.plannedNotifications(input: input)
        let digest = planned.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        let urgent = planned.filter { $0.categoryIdentifier == "EXPIRY_URGENT" }

        await scheduleDailyDigest(digest, preferredHour: preferredHour, now: now, calendar: calendar)
        await scheduleUrgentExpiryAlerts(urgent, referenceDate: now, calendar: calendar)
        NotificationRefreshCoordinator.scheduleBackgroundRefresh(preferredHour: preferredHour)
    }

    /// Backward-compatible entry point used by app lifecycle scheduling.
    func schedulePrioritizedAlerts(
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem],
        budgetState: NotificationBudgetState?
    ) {
        Task {
            await scheduleAll(
                pantryItems: pantryItems,
                shoppingItems: shoppingItems,
                budgetState: budgetState
            )
        }
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
        content.userInfo = [
            "category": "AUTO_ARCHIVE_WARNING",
            "destination": NotificationDestination.pantryExpiring.rawValue
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        Task {
            await addNotificationRequest(
                UNNotificationRequest(identifier: "auto-archive-warning", content: content, trigger: trigger)
            )
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Approval requests

    @discardableResult
    func deliverApprovalRequest(_ alert: PendingApprovalAlert) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return false
        }

        let destination = alert.itemType == "shopping" ? "shopping list" : "pantry"
        let content = UNMutableNotificationContent()
        content.title = "Approval needed"
        content.body = "\(alert.itemName) was added to the \(destination)"
        content.sound = .default
        content.categoryIdentifier = "APPROVAL_REQUEST"
        content.userInfo = [
            "item_id": alert.itemId.uuidString,
            "item_name": alert.itemName,
            "item_type": alert.itemType,
            "source": "approval_request"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "approval-\(alert.itemId.uuidString)",
            content: content,
            trigger: trigger
        )

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    // MARK: - Private scheduling

    private func scheduleDailyDigest(
        _ planned: PlannedNotification?,
        preferredHour: Int,
        now: Date,
        calendar: Calendar
    ) async {
        guard let planned else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationPlanner.dailyDigestIdentifier])
            return
        }

        let pending = await pendingNotificationRequests()
        let existing = pending.first { $0.identifier == NotificationPlanner.dailyDigestIdentifier }
        let existingFireDate = (existing?.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()

        center.removePendingNotificationRequests(withIdentifiers: [NotificationPlanner.dailyDigestIdentifier])

        let content = notificationContent(from: planned)
        var components = DateComponents()
        components.hour = preferredHour
        components.minute = 0

        if NotificationPlanner.shouldPreservePendingDigest(
            pendingFireDate: existingFireDate,
            referenceDate: now,
            preferredHour: preferredHour,
            calendar: calendar
        ), let existingFireDate {
            components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: existingFireDate)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        await addNotificationRequest(
            UNNotificationRequest(
                identifier: NotificationPlanner.dailyDigestIdentifier,
                content: content,
                trigger: trigger
            )
        )
    }

    private func scheduleUrgentExpiryAlerts(
        _ alerts: [PlannedNotification],
        referenceDate: Date,
        calendar: Calendar
    ) async {
        let dayKey = calendar.startOfDay(for: referenceDate).timeIntervalSince1970.description
        var deliveredKeys = Set(UserDefaults.standard.stringArray(forKey: Self.urgentExpiryDeliveredKey) ?? [])

        for alert in alerts {
            let dedupeKey = "\(dayKey)-\(alert.identifier)"
            guard !deliveredKeys.contains(dedupeKey) else { continue }

            let content = notificationContent(from: alert)
            let interval = alert.fireAfterSeconds ?? 3
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
            await addNotificationRequest(
                UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger)
            )
            deliveredKeys.insert(dedupeKey)
        }

        UserDefaults.standard.set(Array(deliveredKeys), forKey: Self.urgentExpiryDeliveredKey)
    }

    private func notificationContent(from planned: PlannedNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default
        content.categoryIdentifier = planned.categoryIdentifier
        var userInfo: [String: Any] = ["source": planned.categoryIdentifier.lowercased()]
        if let destination = planned.destination {
            userInfo["destination"] = destination.rawValue
        }
        content.userInfo = userInfo
        return content
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async {
        try? await center.add(request)
    }
}

extension NotificationService {
    static func destination(for userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        guard let raw = userInfo["destination"] as? String else { return nil }
        return NotificationDestination(rawValue: raw)
    }

    static func postNavigationNotification(for destination: NotificationDestination) {
        NotificationNavigationStore.enqueue(destination)
        switch destination {
        case .pantryExpiring:
            NotificationCenter.default.post(name: .openPantryExpiring, object: nil)
        case .pantryLowStock:
            NotificationCenter.default.post(name: .openPantryLowStock, object: nil)
        case .pantryReview:
            NotificationCenter.default.post(name: .openPantryReview, object: nil)
        case .shop:
            NotificationCenter.default.post(name: .openShoppingTab, object: nil)
        case .approvals:
            NotificationCenter.default.post(name: .openPendingApprovals, object: nil)
        }
    }
}
