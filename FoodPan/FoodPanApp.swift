import SwiftUI
import GoogleSignIn

@main
struct FoodPanApp: App {
    @State private var authService = AuthenticationService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenFeatureOnboarding") private var hasSeenFeatureOnboarding = false
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var colorScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isCheckingSession {
                    Color.appBackground
                        .ignoresSafeArea()
                } else if !authService.isAuthenticated {
                    if hasSeenFeatureOnboarding {
                        WelcomeView(authService: authService)
                    } else {
                        FeatureOnboardingView {
                            hasSeenFeatureOnboarding = true
                        }
                    }
                } else if authService.currentUser?.householdId == nil {
                    CreateHouseholdView(authService: authService)
                } else if !hasCompletedOnboarding, let user = authService.currentUser, let householdId = user.householdId {
                    AddFirstItemView(
                        householdId: householdId,
                        userId: user.userId
                    ) {
                        hasCompletedOnboarding = true
                    }
                } else {
                    ContentView(authService: authService)
                }
            }
            .preferredColorScheme(colorScheme)
            .toastOverlay()
            .task {
                configureGoogleSignIn()
                await authService.checkSession()
            }
            .task(id: hasCompletedOnboarding) {
                guard hasCompletedOnboarding, authService.isAuthenticated else { return }
                _ = await NotificationService.shared.requestPermission()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, authService.isAuthenticated,
                   let householdId = authService.currentUser?.householdId {
                    Task {
                        await rescheduleNotifications(householdId: householdId)
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

    private func rescheduleNotifications(householdId: UUID) async {
        let repo = SupabasePantryRepository()
        guard let items = try? await repo.fetchAll(householdId: householdId) else { return }
        NotificationService.shared.scheduleExpiryAlerts(items: items)
        NotificationService.shared.scheduleLowStockAlerts(items: items)
        NotificationService.shared.scheduleUsageReminders(items: items)
    }
}
