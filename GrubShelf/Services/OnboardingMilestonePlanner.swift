import Foundation

enum OnboardingMilestone: String, CaseIterable {
    case addFiveItems = "milestone_add_items"
    case setExpiryDates = "milestone_set_expiry"
    case createShoppingList = "milestone_shopping_list"
}

struct OnboardingMilestoneAlert: Equatable {
    let identifier: String
    let title: String
    let body: String
    let destination: NotificationDestination?
}

enum OnboardingMilestonePlanner {
    static func pendingMilestones(
        referenceDate: Date,
        firstUseDate: Date?,
        deliveredMilestones: Set<String>,
        pantryItemCount: Int,
        itemsWithExpiryCount: Int,
        shoppingItemCount: Int,
        calendar: Calendar = .current
    ) -> [OnboardingMilestoneAlert] {
        guard let firstUseDate else { return [] }

        let daysSinceFirstUse = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstUseDate),
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0

        var alerts: [OnboardingMilestoneAlert] = []

        if daysSinceFirstUse >= 1,
           pantryItemCount < 5,
           !deliveredMilestones.contains(OnboardingMilestone.addFiveItems.rawValue) {
            alerts.append(
                OnboardingMilestoneAlert(
                    identifier: OnboardingMilestone.addFiveItems.rawValue,
                    title: "Build your pantry",
                    body: "Add a few staples so GrubShelf can track expiry and low stock for you.",
                    destination: nil
                )
            )
        }

        if daysSinceFirstUse >= 2,
           pantryItemCount >= 2,
           itemsWithExpiryCount < max(2, pantryItemCount / 2),
           !deliveredMilestones.contains(OnboardingMilestone.setExpiryDates.rawValue) {
            alerts.append(
                OnboardingMilestoneAlert(
                    identifier: OnboardingMilestone.setExpiryDates.rawValue,
                    title: "Add expiry dates",
                    body: "Items with expiry dates get timely alerts before food goes to waste.",
                    destination: .pantryExpiring
                )
            )
        }

        if daysSinceFirstUse >= 4,
           shoppingItemCount == 0,
           !deliveredMilestones.contains(OnboardingMilestone.createShoppingList.rawValue) {
            alerts.append(
                OnboardingMilestoneAlert(
                    identifier: OnboardingMilestone.createShoppingList.rawValue,
                    title: "Plan your next shop",
                    body: "Create a shopping list so you're never guessing what to buy.",
                    destination: .shop
                )
            )
        }

        return alerts
    }
}
