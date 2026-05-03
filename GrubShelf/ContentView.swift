import SwiftUI

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

    @State private var dashboardVM: DashboardViewModel?
    @State private var pantryVM: PantryViewModel?
    @State private var shoppingListsVM: ShoppingListsViewModel?
    @State private var insightsVM: InsightsViewModel?
    @State private var financeVM: FinanceViewModel?
    @State private var profileVM: ProfileViewModel?

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
                @Bindable var pantVM = pant
                TabView(selection: $selectedTab) {
                    HomeRootView(
                        dashboardVM: dash,
                        pantryVM: pant,
                        financeVM: fin,
                        profileVM: prof,
                        shoppingListsVM: shop,
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

                    InsightsView(insightsVM: ins, financeVM: fin)
                        .tabItem { Label("Expense", systemImage: "chart.bar.fill") }
                        .tag(AppTab.expense)
                }
                .tint(.gsBrandPrimary)
                .onAppear {
                    pant.startObserving()
                }
                .sheet(isPresented: $showProfile) {
                    ProfileView(viewModel: prof)
                }
                .sheet(isPresented: $pantVM.showAddSheet) {
                    AddItemHubSheet(
                        pantryItems: pant.items,
                        householdId: householdId,
                        userId: userId
                    )
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
                        await dash.loadData(forceRefresh: true)
                        await pant.loadItems(forceRefresh: true)
                        await shop.loadLists(forceRefresh: true)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await dash.loadData(forceRefresh: true)
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
                        dashboardVM = DashboardViewModel(
                            pantryRepository: pantryRepo,
                            shoppingRepository: shoppingRepo,
                            householdId: householdId
                        )
                        pantryVM = PantryViewModel(
                            repository: pantryRepo,
                            householdId: householdId,
                            userId: userId
                        )
                        shoppingListsVM = ShoppingListsViewModel(
                            listRepository: shoppingListRepo,
                            shoppingRepository: shoppingRepo,
                            householdId: householdId,
                            userId: userId
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

}
