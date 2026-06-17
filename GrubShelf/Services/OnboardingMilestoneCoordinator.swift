import Foundation
import UserNotifications

@MainActor
final class OnboardingMilestoneCoordinator {
    static let shared = OnboardingMilestoneCoordinator()

    private let firstUseKey = "onboardingMilestone.firstUseDate"
    private let deliveredKey = "onboardingMilestone.delivered"

    private init() {
        if UserDefaults.standard.object(forKey: firstUseKey) == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: firstUseKey)
        }
    }

    func evaluateAndSchedule(pantryItems: [PantryItem], shoppingItems: [ShoppingItem]) async {
        let referenceDate = Date()
        let firstUseDate = UserDefaults.standard.object(forKey: firstUseKey)
            .flatMap { $0 as? TimeInterval }
            .map { Date(timeIntervalSince1970: $0) }

        let approved = pantryItems.filter { $0.approvalStatus == .approved && !$0.archived }
        let itemsWithExpiry = approved.filter { $0.expiryDate != nil }.count
        let delivered = Set(UserDefaults.standard.stringArray(forKey: deliveredKey) ?? [])

        let pending = OnboardingMilestonePlanner.pendingMilestones(
            referenceDate: referenceDate,
            firstUseDate: firstUseDate,
            deliveredMilestones: delivered,
            pantryItemCount: approved.count,
            itemsWithExpiryCount: itemsWithExpiry,
            shoppingItemCount: shoppingItems.filter { !$0.completed }.count
        )

        guard let next = pending.first else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral else { return }

        let content = UNMutableNotificationContent()
        content.title = next.title
        content.body = next.body
        content.sound = .default
        content.categoryIdentifier = "ONBOARDING_MILESTONE"
        if let destination = next.destination {
            content.userInfo = ["destination": destination.rawValue]
        }

        let preferredHour = EngagementStore.shared.preferredNotificationHour()
        var components = DateComponents()
        components.hour = preferredHour
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [next.identifier])
        try? await center.add(
            UNNotificationRequest(identifier: next.identifier, content: content, trigger: trigger)
        )

        var updated = delivered
        updated.insert(next.identifier)
        UserDefaults.standard.set(Array(updated), forKey: deliveredKey)
    }
}
