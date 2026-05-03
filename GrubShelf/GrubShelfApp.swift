import SwiftUI
import GoogleSignIn
import UserNotifications

@main
struct GrubShelfApp: App {
    init() {
        BundledFontRegistration.ensureBrandFontsLoaded()

        // Migration: existing users who already completed onboarding should skip
        // the new post-onboarding setup screen. If they've seen the feature tour
        // but the setup key doesn't exist yet, they're an existing user — auto-skip.
        let setupKey = "hasCompletedPostOnboardingSetup"
        if UserDefaults.standard.object(forKey: setupKey) == nil
            && UserDefaults.standard.bool(forKey: "hasSeenFeatureOnboarding") {
            UserDefaults.standard.set(true, forKey: setupKey)
        }
    }

    @UIApplicationDelegateAdaptor(NotificationDelegate.self) var notificationDelegate
    @State private var authService = AuthenticationService()
    @AppStorage("hasSeenFeatureOnboarding") private var hasSeenFeatureOnboarding = false
    @AppStorage("hasCompletedPostOnboardingSetup") private var hasCompletedSetup = false
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var colorScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isCheckingSession {
                    Color.gsBackground
                        .ignoresSafeArea()
                } else if authService.mustCompletePasswordReset {
                    CompletePasswordResetView(authService: authService)
                } else if !hasSeenFeatureOnboarding {
                    FeatureOnboardingView {
                        hasSeenFeatureOnboarding = true
                    }
                } else if authService.pendingVerificationEmail != nil {
                    EmailVerificationView(authService: authService)
                } else if !authService.isAuthenticated {
                    WelcomeView(authService: authService)
                } else if authService.currentUser?.householdId == nil {
                    CreateHouseholdView(authService: authService)
                } else if let user = authService.currentUser, let hid = user.householdId, !hasCompletedSetup {
                    PostOnboardingSetupView(
                        householdId: hid,
                        userId: user.userId,
                        onContinue: { hasCompletedSetup = true }
                    )
                } else if let user = authService.currentUser, let hid = user.householdId {
                    ContentView(authService: authService, householdId: hid, userId: user.userId)
                } else {
                    Color.gsBackground
                        .ignoresSafeArea()
                }
            }
            .preferredColorScheme(colorScheme)
            .toastOverlay()
            .onOpenURL { url in
                if PasswordResetCallbackURL.matches(url) {
                    Task { await authService.handlePasswordResetDeepLink(url: url) }
                } else {
                    GIDSignIn.sharedInstance.handle(url)
                }
            }
            .task {
                configureGoogleSignIn()
                await authService.checkSession()
            }
            .task(id: authService.isAuthenticated) {
                guard authService.isAuthenticated else { return }
                _ = await NotificationService.shared.requestPermission()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    EngagementStore.shared.recordAppOpen()
                    if authService.isAuthenticated,
                       let user = authService.currentUser,
                       let householdId = user.householdId {
                        Task {
                            await ShoppingListWidgetToggleQueueFlush.run(householdId: householdId)
                            await rescheduleNotifications(householdId: householdId, userId: user.userId)
                        }
                    }
                }
            }
        }
    }

    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let clientID = config["GOOGLE_CLIENT_ID"] as? String,
              !clientID.contains("YOUR_") else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    private func rescheduleNotifications(householdId: UUID, userId: UUID) async {
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
        if let s = settings {
            let period = computePeriod(for: Date(), budgetPeriod: s.budgetPeriod)
            let trips = (try? await tripRepo.fetchByPeriod(householdId: householdId, period: period)) ?? []
            let spent = trips.compactMap(\.totalCostMinor).reduce(0, +)
            let budgetReminderEnabled = UserDefaults.standard.object(forKey: "budgetReminderEnabled") as? Bool ?? true
            budgetState = NotificationBudgetState(
                budgetRemainingMinor: s.budgetAmountMinor - spent,
                budgetAmountMinor: s.budgetAmountMinor,
                budgetReminderEnabled: budgetReminderEnabled
            )
        }

        NotificationService.shared.schedulePrioritizedAlerts(
            pantryItems: pantryItems,
            shoppingItems: shoppingItems,
            budgetState: budgetState
        )
    }

    private func computePeriod(for date: Date, budgetPeriod: BudgetPeriod) -> String {
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

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BundledFontRegistration.ensureBrandFontsLoaded()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        EngagementStore.shared.recordNotificationTap(category: response.notification.request.content.categoryIdentifier)
        completionHandler()
    }
}
