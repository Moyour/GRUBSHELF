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

    @State private var isInitialized = false
    @State private var selectedTab: AppTab = .home
    @State private var showLogPurchaseSheet = false
    @State private var showProfile = false
    @State private var showNotificationPrimer = false
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
                @Bindable var pantVM = pant
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

                    InsightsView(insightsVM: ins, financeVM: fin, canEditBudget: canEditBudget)
                        .tabItem { Label("Expense", systemImage: "chart.bar.fill") }
                        .tag(AppTab.expense)
                }
                .tint(.gsBrandPrimary)
                .onAppear {
                    pant.startObserving()
                    if canManageHousehold {
                        Task { _ = await NotificationService.shared.ensureAuthorizationForAlerts() }
                    }
                    if NotificationService.shared.needsPermissionPrimer {
                        showNotificationPrimer = true
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
                }
                .sheet(isPresented: $showNotificationPrimer) {
                    NotificationPermissionPrimerView(
                        onEnable: {
                            showNotificationPrimer = false
                            Task {
                                await NotificationService.shared.requestPermissionAfterPrimer(
                                    application: UIApplication.shared
                                )
                            }
                        },
                        onSkip: {
                            NotificationService.shared.markPermissionPrimerShown()
                            UserDefaults.standard.set(true, forKey: "notificationPromptShown")
                            showNotificationPrimer = false
                        }
                    )
                }
                .sheet(isPresented: $pantVM.showAddSheet) {
                    AddItemHubSheet(
                        pantryItems: pant.items,
                        householdId: householdId,
                        userId: userId,
                        userRole: userRole
                    )
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
                }
                .sheet(isPresented: $showLogPurchaseSheet) {
                    LogPurchaseSheet(financeVM: fin) {
                        showLogPurchaseSheet = false
                    }
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
                        }
                    }
                }
            } else {
                ProgressView("Loading…")
                    .tint(.gsBrandPrimary)
                    .foregroundStyle(.gsTextSecondary)
                    .task {
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
                        isInitialized = true
                    }
            }
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
