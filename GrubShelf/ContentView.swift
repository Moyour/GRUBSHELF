import SwiftUI
import UIKit

/// Bottom tab selection for the main `TabView` shell.
enum AppTab: Int, Hashable, CaseIterable {
    case home = 0
    case pantry = 1
    case shop = 2
    case expense = 3
}

struct ContentView: View {
    @Bindable var authService: AuthenticationService
    let householdId: UUID
    let userId: UUID
    private var userRole: UserRole {
        authService.currentUser?.role ?? .member
    }

    private var permissionContext: HouseholdPermissionContext {
        if let user = authService.currentUser {
            return HouseholdPermissionContext(user: user)
        }
        return HouseholdPermissionContext(role: userRole, isOwner: false)
    }

    private var canEditBudget: Bool {
        PermissionService.canPerform(.modifyBudget, context: permissionContext)
    }

    private var canManageHousehold: Bool {
        PermissionService.canPerform(.manageMembers, context: permissionContext)
            || PermissionService.canPerform(.approveItems, context: permissionContext)
    }

    @State private var dashboardVM: DashboardViewModel?
    @State private var showPendingApprovals = false
    @State private var pantryVM: PantryViewModel?
    @State private var shoppingListsVM: ShoppingListsViewModel?
    @State private var insightsVM: InsightsViewModel?
    @State private var financeVM: FinanceViewModel?
    @State private var profileVM: ProfileViewModel?

    @State private var subscriptionService = SubscriptionService()
    @State private var featureGateService: FeatureGateService?
    @State private var storeKitService = StoreKitService()
    @State private var showPaywall = false

    @State private var isInitialized = false
    @State private var selectedTab: AppTab = .home
    @State private var showLogPurchaseSheet = false
    @State private var showProfile = false
    @Environment(\.scenePhase) private var scenePhase

    private var networkMonitor: NetworkMonitor { NetworkMonitor.shared }

    @State private var pantryRepo = SupabasePantryRepository()
    @State private var shoppingRepo = SupabaseShoppingRepository()
    @State private var shoppingListRepo = SupabaseShoppingListRepository()
    @State private var shoppingTripRepo = SupabaseShoppingTripRepository()
    @State private var transactionRepo = SupabaseTransactionRepository()

    var body: some View {
        Group {
            if isInitialized, let dash = dashboardVM, let pant = pantryVM,
               let shop = shoppingListsVM, let fin = financeVM,
               let ins = insightsVM, let prof = profileVM {
                initializedContent(dash: dash, pant: pant, shop: shop, fin: fin, ins: ins, prof: prof)
            } else {
                ProgressView("Loading…")
                    .tint(.gsBrandPrimary)
                    .foregroundStyle(.gsTextSecondary)
                    .task { await initializeViewModels() }
            }
        }
    }

    // MARK: - Initialized content

    @ViewBuilder
    private func initializedContent(
        dash: DashboardViewModel,
        pant: PantryViewModel,
        shop: ShoppingListsViewModel,
        fin: FinanceViewModel,
        ins: InsightsViewModel,
        prof: ProfileViewModel
    ) -> some View {
        @Bindable var pantVM = pant
        tabContent(dash: dash, pant: pant, shop: shop, fin: fin, ins: ins, prof: prof)
            .environment(\.subscriptionService, subscriptionService)
            .environment(\.featureGateService, featureGateService)
            .environment(\.storeKitService, storeKitService)
            .tint(.gsBrandPrimary)
            .onAppear {
                pant.startObserving()
                if canManageHousehold {
                    Task { _ = await NotificationService.shared.ensureAuthorizationForAlerts() }
                }
                applyNotificationDestination(using: pant)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPendingApprovals)) { _ in
                _ = NotificationNavigationStore.consume()
                showPendingApprovals = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPantryExpiring)) { _ in
                _ = NotificationNavigationStore.consume()
                selectedTab = .pantry
                pant.applyNavigationFocus(.expiring)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPantryLowStock)) { _ in
                _ = NotificationNavigationStore.consume()
                selectedTab = .pantry
                pant.applyNavigationFocus(.lowStock)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPantryReview)) { _ in
                _ = NotificationNavigationStore.consume()
                selectedTab = .pantry
                pant.applyNavigationFocus(PantryNavigationFocus(locationFilter: .all, attention: .none))
            }
            .onReceive(NotificationCenter.default.publisher(for: .openShoppingTab)) { _ in
                _ = NotificationNavigationStore.consume()
                selectedTab = .shop
            }
            .onChange(of: pant.items) { _, items in
                guard canManageHousehold else { return }
                dash.syncPendingApprovalsCount(pantryItems: items, shoppingItems: shop.cachedShoppingItems)
            }
            .onChange(of: shop.cachedShoppingItems) { _, items in
                guard canManageHousehold else { return }
                dash.syncPendingApprovalsCount(pantryItems: pant.items, shoppingItems: items)
                ApprovalNotificationCoordinator.shared.processPendingItems(
                    pantryItems: pant.items,
                    shoppingItems: items,
                    isAdmin: true
                )
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(viewModel: prof)
                    .environment(\.featureGateService, featureGateService)
                    .environment(\.subscriptionService, subscriptionService)
                    .environment(\.storeKitService, storeKitService)
            }
            .sheet(isPresented: $pantVM.showAddSheet) {
                AddItemHubSheet(
                    pantryItems: pant.items,
                    householdId: householdId,
                    userId: userId,
                    userRole: userRole,
                    featureGateService: featureGateService
                )
                .environment(\.featureGateService, featureGateService)
                .environment(\.subscriptionService, subscriptionService)
            }
            .sheet(isPresented: $showPendingApprovals, onDismiss: {
                Task {
                    await dash.loadData(forceRefresh: true, authService: authService)
                    await pant.loadItems(forceRefresh: true)
                    await shop.loadLists(forceRefresh: true)
                    await shop.loadActiveListItems()
                }
            }) {
                NavigationStack {
                    PendingApprovalsView(householdId: householdId)
                }
                .presentationDetents([.large])
                .environment(\.featureGateService, featureGateService)
                .environment(\.subscriptionService, subscriptionService)
            }
            .sheet(isPresented: $showLogPurchaseSheet) {
                ReceiptFlowSheet(
                    financeVM: fin,
                    pantryRepository: pantryRepo,
                    userRole: userRole
                ) {
                    showLogPurchaseSheet = false
                }
                .environment(\.featureGateService, featureGateService)
                .environment(\.subscriptionService, subscriptionService)
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                featureGateService?.showPaywall = false
            }) {
                paywallSheet
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                SyncBanner(
                    message: "You're offline — some features may be limited",
                    isVisible: !networkMonitor.isConnected
                )
                .animation(.easeInOut, value: networkMonitor.isConnected)
            }
            .onChange(of: networkMonitor.reconnectionCount) {
                Task {
                    await dash.loadData(forceRefresh: true, authService: authService)
                    await pant.loadItems(forceRefresh: true)
                    await shop.loadLists(forceRefresh: true)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await dash.loadData(forceRefresh: true, authService: authService)
                        await pant.loadItems(forceRefresh: true)
                        await shop.loadLists(forceRefresh: true)
                        await subscriptionService.loadSubscription(householdId: householdId)
                        await storeKitService.updatePurchasedProducts()
                    }
                }
            }
            .onChange(of: featureGateService?.showPaywall) { _, newValue in
                showPaywall = newValue ?? false
            }
            .onAppear {
                if UserDefaults.standard.bool(forKey: "wantsPremiumAfterSetup") {
                    UserDefaults.standard.set(false, forKey: "wantsPremiumAfterSetup")
                    showPaywall = true
                }

                // 7-day premium upsell: show paywall once after 7 distinct active days
                let upsellKey = "hasShown7DayPremiumUpsell"
                if !UserDefaults.standard.bool(forKey: upsellKey),
                   EngagementStore.shared.distinctActiveDays() >= 7 {
                    UserDefaults.standard.set(true, forKey: upsellKey)
                    showPaywall = true
                }
            }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent(
        dash: DashboardViewModel,
        pant: PantryViewModel,
        shop: ShoppingListsViewModel,
        fin: FinanceViewModel,
        ins: InsightsViewModel,
        prof: ProfileViewModel
    ) -> some View {
        TabView(selection: $selectedTab) {
            HomeRootView(
                dashboardVM: dash,
                pantryVM: pant,
                financeVM: fin,
                profileVM: prof,
                shoppingListsVM: shop,
                authService: authService,
                onReviewPendingApprovals: {
                    showPendingApprovals = true
                },
                onNavigateToInsights: { selectedTab = .expense },
                onNavigateToShopping: { selectedTab = .shop },
                onOpenPantryTab: { focus in
                    selectedTab = .pantry
                    if let focus {
                        pant.applyNavigationFocus(focus)
                    }
                },
                onOpenProfile: { showProfile = true },
                onLogPurchase: { showLogPurchaseSheet = true }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            PantryView(viewModel: pant)
                .tabItem { Label("Pantry", systemImage: "refrigerator.fill") }
                .tag(AppTab.pantry)

            ShoppingListsView(viewModel: shop, financeVM: fin)
                .tabItem { Label("Shop", systemImage: "cart.fill") }
                .tag(AppTab.shop)

            InsightsView(insightsVM: ins, financeVM: fin, canEditBudget: canEditBudget, pantryRepository: pantryRepo, userRole: userRole)
                .tabItem { Label("Expense", systemImage: "chart.bar.fill") }
                .tag(AppTab.expense)
        }
    }

    // MARK: - Paywall sheet

    @ViewBuilder
    private var paywallSheet: some View {
        if let gate = featureGateService {
            PaywallView(
                featureGateService: gate,
                storeKitService: storeKitService,
                subscriptionService: subscriptionService,
                householdId: householdId,
                userId: userId
            )
        }
    }

    // MARK: - Initialization

    private func initializeViewModels() async {
        guard !isInitialized else { return }
        let user = authService.currentUser
        let role = user?.role ?? .member
        let isOwner = user?.isOwner ?? false
        dashboardVM = DashboardViewModel(
            pantryRepository: pantryRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId,
            userRole: role
        )
        pantryVM = PantryViewModel(
            repository: pantryRepo,
            householdId: householdId,
            userId: userId,
            userRole: role
        )
        shoppingListsVM = ShoppingListsViewModel(
            listRepository: shoppingListRepo,
            shoppingRepository: shoppingRepo,
            householdId: householdId,
            userId: userId,
            userRole: role,
            isOwner: isOwner
        )
        financeVM = FinanceViewModel(householdId: householdId, userId: userId)
        let financialSvc = FinancialService(
            transactionRepository: transactionRepo,
            pantryRepository: pantryRepo
        )
        insightsVM = InsightsViewModel(
            financialService: financialSvc,
            transactionRepository: transactionRepo,
            pantryRepository: pantryRepo,
            shoppingRepository: shoppingRepo,
            shoppingTripRepository: shoppingTripRepo,
            householdId: householdId
        )
        profileVM = ProfileViewModel(authService: authService)
        let gate = FeatureGateService(subscriptionService: subscriptionService)
        featureGateService = gate
        shoppingListsVM?.featureGateService = gate
        profileVM?.featureGateService = gate
        storeKitService.configure(
            subscriptionService: subscriptionService,
            householdId: householdId,
            userId: userId
        )
        // Show the UI immediately — subscription cache (loaded in init) is available.
        // Network refresh and StoreKit product fetch happen in the background.
        isInitialized = true
        Task {
            await subscriptionService.loadSubscription(householdId: householdId)
            await storeKitService.loadProducts()
        }
    }

    /// Applies a notification tap destination stored during cold start (before subscribers existed).
    private func applyNotificationDestination(using pantryVM: PantryViewModel) {
        guard let destination = NotificationNavigationStore.consume() else { return }
        switch destination {
        case .pantryExpiring:
            selectedTab = .pantry
            pantryVM.applyNavigationFocus(.expiring)
        case .pantryLowStock:
            selectedTab = .pantry
            pantryVM.applyNavigationFocus(.lowStock)
        case .pantryReview:
            selectedTab = .pantry
            pantryVM.applyNavigationFocus(PantryNavigationFocus(locationFilter: .all, attention: .none))
        case .shop:
            selectedTab = .shop
        case .approvals:
            showPendingApprovals = true
        }
    }

}
