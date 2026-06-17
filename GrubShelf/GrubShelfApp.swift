import SwiftUI
import GoogleSignIn
import UserNotifications
import os

@main
struct GrubShelfApp: App {
    init() {
        BundledFontRegistration.ensureBrandFontsLoaded()

        // Migration: existing users skip the stock-up flow (they already have items).
        let stockUpKey = "hasCompletedStockUp"
        if UserDefaults.standard.object(forKey: stockUpKey) == nil
            && UserDefaults.standard.bool(forKey: "hasSeenFeatureOnboarding") {
            UserDefaults.standard.set(true, forKey: stockUpKey)
        }

        // Migration: existing users skip the post-onboarding setup screen.
        let setupKey = "hasCompletedPostOnboardingSetup"
        if UserDefaults.standard.object(forKey: setupKey) == nil
            && UserDefaults.standard.bool(forKey: "hasSeenFeatureOnboarding") {
            UserDefaults.standard.set(true, forKey: setupKey)
        }

        // Migration: auto-skip legacy onboarding screens (feature tour + premium intro)
        // for all users — these screens are no longer part of the startup flow.
        UserDefaults.standard.set(true, forKey: "hasSeenFeatureOnboarding")
        UserDefaults.standard.set(true, forKey: "hasSeenPremiumIntro")

        // Migration: existing users who already onboarded should never see the
        // post-OAuth name gate (it's only for new OAuth sign-ups with bad names).
        let nameGateKey = "hasCompletedNameGate"
        if UserDefaults.standard.object(forKey: nameGateKey) == nil
            && UserDefaults.standard.bool(forKey: "hasSeenFeatureOnboarding") {
            UserDefaults.standard.set(true, forKey: nameGateKey)
        }

        // Migration: existing users skip the notification permission onboarding screen.
        let notifSetupKey = "hasCompletedNotificationSetup"
        if UserDefaults.standard.object(forKey: notifSetupKey) == nil
            && UserDefaults.standard.bool(forKey: "hasSeenFeatureOnboarding") {
            UserDefaults.standard.set(true, forKey: notifSetupKey)
        }
    }

    @UIApplicationDelegateAdaptor(NotificationDelegate.self) var notificationDelegate
    @State private var authService = AuthenticationService()
    @State private var pendingInviteToken: UUID?
    @State private var showAcceptInviteSheet = false
    @State private var networkMonitor = NetworkMonitor.shared
    @AppStorage("hasSeenFeatureOnboarding") private var hasSeenFeatureOnboarding = false
    @AppStorage("hasSeenPremiumIntro") private var hasSeenPremiumIntro = false
    @AppStorage("hasCompletedPostOnboardingSetup") private var hasCompletedSetup = false
    @AppStorage("hasCompletedNameGate") private var hasCompletedNameGate = false
    @AppStorage("hasCompletedStockUp") private var hasCompletedStockUp = false
    @AppStorage("hasCompletedNotificationSetup") private var hasCompletedNotificationSetup = false
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
                } else if authService.pendingVerificationEmail != nil {
                    EmailVerificationView(authService: authService)
                } else if authService.pendingPasswordResetEmail != nil {
                    PasswordResetCodeView(authService: authService)
                } else if !authService.isAuthenticated {
                    WelcomeView(authService: authService)
                } else if authService.isCheckingForInvites {
                    // Checking for pending invitations
                    VStack(spacing: AppSpacing.mediumSpacing) {
                        ProgressView()
                        Text("Checking for invitations...")
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gsBackground)
                } else if !hasCompletedNameGate && !authService.didProvideNameManually {
                    NameGateView(authService: authService, hasCompletedNameGate: $hasCompletedNameGate)
                } else if authService.currentUser?.householdId == nil && (pendingInviteToken != nil || !authService.pendingInvitesToAccept.isEmpty) {
                    // User is authenticated with a pending invite but no household yet - show loading
                    VStack(spacing: AppSpacing.mediumSpacing) {
                        ProgressView()
                        Text("Joining household...")
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gsBackground)
                } else if authService.currentUser?.householdId == nil {
                    CreateHouseholdView(authService: authService)
                } else if let user = authService.currentUser, let hid = user.householdId, !hasCompletedStockUp {
                    StockUpFlowView(
                        householdId: hid,
                        userId: user.userId,
                        userRole: user.role,
                        onContinue: {
                            hasCompletedStockUp = true
                            hasCompletedSetup = true
                        }
                    )
                } else if !hasCompletedNotificationSetup {
                    NotificationPermissionPrimerView(
                        onEnable: {
                            hasCompletedNotificationSetup = true
                            Task {
                                await NotificationService.shared.requestPermissionAfterPrimer(
                                    application: UIApplication.shared
                                )
                            }
                        },
                        onSkip: {
                            NotificationService.shared.markPermissionPrimerShown()
                            hasCompletedNotificationSetup = true
                        }
                    )
                } else if let user = authService.currentUser, let hid = user.householdId {
                    ContentView(authService: authService, householdId: hid, userId: user.userId)
                } else {
                    Color.gsBackground
                        .ignoresSafeArea()
                }
            }
            .preferredColorScheme(colorScheme)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !networkMonitor.isConnected {
                    OfflineBannerView()
                }
            }
            .toastOverlay()
            .sheet(item: Binding(
                get: { authService.pendingInvitesToAccept.first },
                set: { newValue in
                    // Swipe-dismiss must remove only the visible invite, not the whole queue.
                    if newValue == nil, let dismissed = authService.pendingInvitesToAccept.first {
                        authService.dismissPendingInvite(inviteId: dismissed.inviteId)
                    }
                }
            )) { invite in
                PendingInvitePromptView(
                    invite: invite,
                    authService: authService
                )
            }
            .sheet(isPresented: $showAcceptInviteSheet) {
                // On dismiss, clear the pending token
                pendingInviteToken = nil
            } content: {
                if let token = pendingInviteToken {
                    AcceptInviteView(authService: authService, inviteToken: token)
                }
            }
            .onOpenURL { url in
                // Handle Google Sign-In
                GIDSignIn.sharedInstance.handle(url)
                
                // Handle deep links
                let deepLink = DeepLinkHandler.parse(url)
                switch deepLink {
                case .invite(let token):
                    handleInviteDeepLink(token: token)
                case .pantry(let destination):
                    NotificationService.postNavigationNotification(for: destination)
                case .shopping:
                    NotificationService.postNavigationNotification(for: .shop)
                case .approvals:
                    NotificationService.postNavigationNotification(for: .approvals)
                case .unknown:
                    break
                }
            }
            .task {
                configureGoogleSignIn()
                await authService.checkSession()
                applyOnboardingSkipForReturningHouseholdUser()
                networkMonitor.startMonitoring()
            }
            .onChange(of: authService.currentUser?.householdId) { _, householdId in
                guard householdId != nil, let user = authService.currentUser else { return }
                applyOnboardingSkipForExistingHouseholdMember(user)
            }
            .onChange(of: authService.currentUser?.userId) { _, _ in
                guard authService.isAuthenticated, let user = authService.currentUser else { return }
                applyOnboardingSkipForExistingHouseholdMember(user)
            }
            .task(id: authService.isAuthenticated) {
                guard authService.isAuthenticated else { return }
                if let user = authService.currentUser {
                    applyOnboardingSkipForExistingHouseholdMember(user)
                }

                // Close the accept invite sheet if it's showing (user just authenticated)
                if showAcceptInviteSheet {
                    showAcceptInviteSheet = false
                }
                
                // Process pending invite if user just authenticated through other means
                if let token = pendingInviteToken, !showAcceptInviteSheet {
                    await acceptPendingInvite(token: token)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    EngagementStore.shared.recordAppOpen()
                    if authService.isAuthenticated,
                       let user = authService.currentUser,
                       let householdId = user.householdId {
                        NotificationContextStore.save(householdId: householdId, userId: user.userId)
                        BetaTelemetryService.shared.logDay7OpenIfApplicable(accountCreatedAt: user.createdAt)
                        Task {
                            await ShoppingListWidgetToggleQueueFlush.run(householdId: householdId)
                            await NotificationDataLoader.scheduleNotifications(
                                householdId: householdId,
                                userId: user.userId
                            )
                        }
                    }
                }
            }
        }
    }

    /// Returning users with a household skip the pre-login feature tour and premium intro.
    private func applyOnboardingSkipForReturningHouseholdUser() {
        guard authService.currentUser?.householdId != nil else { return }
        hasSeenFeatureOnboarding = true
        hasSeenPremiumIntro = true
    }

    /// Members and guests who already belong to a household skip first-time setup.
    private func applyOnboardingSkipForExistingHouseholdMember(_ user: AppUser) {
        guard user.householdId != nil else { return }
        let context = HouseholdPermissionContext(user: user)
        let isHouseholdManager = PermissionService.canPerform(.manageMembers, context: context)
            || PermissionService.canPerform(.createShoppingList, context: context)
        if !isHouseholdManager {
            hasCompletedSetup = true
            hasSeenFeatureOnboarding = true
            hasSeenPremiumIntro = true
            hasCompletedNameGate = true
            hasCompletedNotificationSetup = true
        }
    }

    private func configureGoogleSignIn() {
        _ = GoogleSignInSupport.configureFromAppConfig()
    }
    
    // MARK: - Deep Link Handlers
    
    private func handleInviteDeepLink(token: UUID) {
        guard authService.isAuthenticated else {
            // User not authenticated yet, show invite acceptance sheet where they can create their account
            pendingInviteToken = token
            showAcceptInviteSheet = true
            return
        }
        
        // User is authenticated, accept invite immediately
        Task {
            await acceptPendingInvite(token: token)
        }
    }
    
    private func acceptPendingInvite(token: UUID) async {
        defer { pendingInviteToken = nil }
        
        let householdService = HouseholdService()
        
        do {
            let updatedUser = try await householdService.acceptInvite(inviteId: token)
            
            // Update auth service with new user data
            authService.currentUser = updatedUser
            
            hasCompletedSetup = true
            hasSeenFeatureOnboarding = true
            hasSeenPremiumIntro = true
            hasCompletedNameGate = true
            hasCompletedNotificationSetup = true

            ToastManager.shared.show("Invitation accepted! Welcome to the household.", style: .success)
        } catch {
            ToastManager.shared.show("Failed to accept invitation: \(error.localizedDescription)", style: .error)
        }
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    private static let logger = Logger(subsystem: "com.grubshelf", category: "NotificationDelegate")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationRefreshCoordinator.registerBackgroundTask()
        registerNotificationCategories()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await PushNotificationService.shared.upsertDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.logger.warning("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }

    private func registerNotificationCategories() {
        let approvalCategory = UNNotificationCategory(
            identifier: "APPROVAL_REQUEST",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([approvalCategory])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        EngagementStore.shared.recordNotificationTap(category: response.notification.request.content.categoryIdentifier)

        if response.notification.request.content.categoryIdentifier == "APPROVAL_REQUEST" {
            NotificationService.postNavigationNotification(for: .approvals)
            completionHandler()
            return
        }

        let userInfo = response.notification.request.content.userInfo
        if let destinationRaw = userInfo["destination"] as? String,
           let destination = NotificationDestination(rawValue: destinationRaw) {
            NotificationService.postNavigationNotification(for: destination)
            completionHandler()
            return
        }

        if let destination = NotificationService.destination(for: userInfo) {
            NotificationService.postNavigationNotification(for: destination)
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == "APPROVAL_REQUEST" {
            completionHandler([.banner, .sound, .badge])
            return
        }
        completionHandler([.banner, .sound])
    }
}
