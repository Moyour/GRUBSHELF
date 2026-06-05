import SwiftUI
import GoogleSignIn
import UserNotifications
import os

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
    @State private var pendingInviteToken: UUID?
    @State private var showAcceptInviteSheet = false
    @State private var networkMonitor = NetworkMonitor.shared
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
                } else if let user = authService.currentUser, let hid = user.householdId, shouldShowPostOnboardingSetup(for: user) {
                    PostOnboardingSetupView(
                        householdId: hid,
                        userId: user.userId,
                        userRole: user.role,
                        isOwner: user.isOwner,
                        onContinue: {
                            hasCompletedSetup = true
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

    /// Post-onboarding setup is for new household creators (admin/owner), not joining members.
    private func shouldShowPostOnboardingSetup(for user: AppUser) -> Bool {
        guard !hasCompletedSetup else { return false }
        let context = HouseholdPermissionContext(user: user)
        let isHouseholdManager = PermissionService.canPerform(.manageMembers, context: context)
            || PermissionService.canPerform(.createShoppingList, context: context)
        return isHouseholdManager
    }

    /// Returning users with a household skip the pre-login feature tour.
    private func applyOnboardingSkipForReturningHouseholdUser() {
        guard authService.currentUser?.householdId != nil else { return }
        hasSeenFeatureOnboarding = true
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

            ToastManager.shared.show("Invitation accepted! Welcome to the household.", style: .success)
        } catch {
            ToastManager.shared.show("Failed to accept invitation: \(error.localizedDescription)", style: .error)
        }
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BundledFontRegistration.ensureBrandFontsLoaded()
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
        // Expected on simulator or when push capability isn't provisioned yet.
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
