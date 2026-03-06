import SwiftUI

struct ContentView: View {
    @Bindable var authService: AuthenticationService
    @State private var dashboardVM: DashboardViewModel?
    @State private var pantryVM: PantryViewModel?
    @State private var shoppingListsVM: ShoppingListsViewModel?
    @State private var insightsVM: InsightsViewModel?
    @State private var financeVM: FinanceViewModel?
    @State private var profileVM: ProfileViewModel?

    @State private var isInitialized = false
    @State private var selectedTab = 0
    @State private var showAddItemFromDashboard = false
    @State private var showLogPurchaseSheet = false
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private var networkMonitor: NetworkMonitor { NetworkMonitor.shared }

    @State private var pantryRepo = SupabasePantryRepository()
    @State private var shoppingRepo = SupabaseShoppingRepository()
    @State private var shoppingListRepo = SupabaseShoppingListRepository()
    @State private var shoppingTripRepo = SupabaseShoppingTripRepository()
    @State private var transactionRepo = SupabaseTransactionRepository()

    private var householdId: UUID {
        authService.currentUser?.householdId ?? UUID()
    }

    private var userId: UUID {
        authService.currentUser?.userId ?? UUID()
    }

    var body: some View {
        Group {
            if isInitialized, let dash = dashboardVM, let pant = pantryVM,
               let shop = shoppingListsVM, let fin = financeVM,
               let ins = insightsVM, let prof = profileVM {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        viewModel: dash,
                        financeVM: fin,
                        showSettings: $showSettings,
                        onNavigateToInsights: { selectedTab = 3 }
                    ) { action in
                        handleQuickAction(action)
                    }
                    .tabItem {
                        Label("Dashboard", systemImage: "house.fill")
                    }
                    .tag(0)

                    PantryView(viewModel: pant, showSettings: $showSettings)
                        .tabItem {
                            Label("Pantry", systemImage: "refrigerator.fill")
                        }
                        .tag(1)

                    ShoppingListsView(viewModel: shop, showSettings: $showSettings)
                        .tabItem {
                            Label("Shop", systemImage: "cart.fill")
                        }
                        .tag(2)

                    InsightsView(insightsVM: ins, financeVM: fin, showSettings: $showSettings)
                        .tabItem {
                            Label("Insights", systemImage: "chart.bar.fill")
                        }
                        .tag(3)

                    ProfileView(viewModel: prof, showSettings: $showSettings)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(4)
                }
                .tint(Color.primaryGreen)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showAddItemFromDashboard) {
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
                .safeAreaInset(edge: .top) {
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
                ProgressView("Loading...")
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

    private func handleQuickAction(_ action: DashboardQuickAction) {
        switch action {
        case .addItem:
            showAddItemFromDashboard = true
        case .shopping:
            selectedTab = 2
        case .logPurchase:
            showLogPurchaseSheet = true
        }
    }
}
