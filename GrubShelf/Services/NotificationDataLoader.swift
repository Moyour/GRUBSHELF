import Foundation

/// Loads pantry/shopping/budget data and schedules local notifications.
enum NotificationDataLoader {
    static func scheduleNotifications(householdId: UUID, userId: UUID) async {
        let pantryRepo = SupabasePantryRepository()
        let shoppingRepo = SupabaseShoppingRepository()
        let financeSettingsRepo = SupabaseFinanceSettingsRepository()
        let tripRepo = SupabaseShoppingTripRepository()

        async let pantryFetch = pantryRepo.fetchAll(householdId: householdId)
        async let shoppingFetch = shoppingRepo.fetchAll(householdId: householdId)
        async let settingsFetch = financeSettingsRepo.fetch(userId: userId)

        guard let pantryItems = try? await pantryFetch else { return }
        let shoppingItems = (try? await shoppingFetch) ?? []
        let settings = try? await settingsFetch

        var budgetState: NotificationBudgetState?
        if let settings {
            let period = computePeriod(for: Date(), budgetPeriod: settings.budgetPeriod)
            let trips = (try? await tripRepo.fetchByPeriod(householdId: householdId, period: period)) ?? []
            let spent = trips.compactMap(\.totalCostMinor).reduce(0, +)
            let budgetReminderEnabled = UserDefaults.standard.object(forKey: "budgetReminderEnabled") as? Bool ?? true
            budgetState = NotificationBudgetState(
                budgetRemainingMinor: settings.budgetAmountMinor - spent,
                budgetAmountMinor: settings.budgetAmountMinor,
                budgetReminderEnabled: budgetReminderEnabled
            )
        }

        await NotificationService.shared.scheduleAll(
            pantryItems: pantryItems,
            shoppingItems: shoppingItems,
            budgetState: budgetState
        )
        await OnboardingMilestoneCoordinator.shared.evaluateAndSchedule(
            pantryItems: pantryItems,
            shoppingItems: shoppingItems
        )
    }

    private static func computePeriod(for date: Date, budgetPeriod: BudgetPeriod) -> String {
        let calendar = Calendar.current
        switch budgetPeriod {
        case .weekly:
            let year = calendar.component(.yearForWeekOfYear, from: date)
            let week = calendar.component(.weekOfYear, from: date)
            return String(format: "%d-W%02d", year, week)
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
        }
    }
}
