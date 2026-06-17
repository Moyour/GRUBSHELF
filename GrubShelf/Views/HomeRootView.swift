import SwiftUI

/// Home tab: “The Feed” — household activity stream. Full inventory lives on Pantry.
struct HomeRootView: View {
    @Bindable var dashboardVM: DashboardViewModel
    @Bindable var pantryVM: PantryViewModel
    @Bindable var financeVM: FinanceViewModel
    @Bindable var profileVM: ProfileViewModel
    @Bindable var shoppingListsVM: ShoppingListsViewModel
    var authService: AuthenticationService?

    @State private var showDashboardPantryReview = false
    @State private var showReviewSheet = false
    @State private var showExpiryCalendar = false
    @State private var lastFeedSyncedAt: Date?
    @AppStorage("GrubShelf.feedColdStartDismissed") private var coldStartDismissed = false

    let onReviewPendingApprovals: () -> Void
    let onNavigateToInsights: () -> Void
    let onNavigateToShopping: () -> Void
    let onOpenPantryTab: (PantryNavigationFocus?) -> Void
    let onOpenProfile: () -> Void
    let onLogPurchase: () -> Void

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var feedDataReady: Bool {
        pantryVM.hasLoaded && dashboardVM.hasLoaded && financeVM.hasLoaded && shoppingListsVM.hasLoaded
    }

    private var newestItems: [PantryItem] {
        pantryVM.approvedItems
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { $0 }
    }

    private var additionsTitleLine: String {
        HouseholdFeedFormatter.additionsTitle(
            items: Array(newestItems),
            members: profileVM.members,
            currentUserId: pantryVM.userId
        )
    }

    private var additionsSubtitleLine: String {
        guard !newestItems.isEmpty else { return "Start by adding your first pantry item." }
        let list = HouseholdFeedFormatter.compactItemList(newestItems.map(\.name))
        let recency = HouseholdFeedFormatter.recencyLabel(for: newestItems[0].createdAt)
        var line = "\(list) · \(recency)"
        if let hint = HouseholdFeedFormatter.sameDayShoppingHint(items: Array(newestItems), trips: financeVM.trips) {
            line += " · \(hint)"
        }
        return line
    }

    private var showColdStartGuide: Bool {
        !coldStartDismissed && dashboardVM.totalPantryItems < 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gsBackground.ignoresSafeArea()
                if feedDataReady {
                    todayDashboardContent
                } else {
                    ScrollView {
                        FeedSkeletonStack()
                            .padding(.horizontal, AppSpacing.screenPadding)
                            .padding(.top, AppSpacing.smallSpacing)
                            .padding(.bottom, 32)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onOpenProfile) {
                        Image(systemName: "person.crop.circle")
                            .font(BrandSymbolFont.symbol(17))
                            .foregroundStyle(.gsTextPrimary)
                    }
                    .accessibilityLabel("Profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            pantryVM.showAddSheet = true
                        } label: {
                            Label(String(localized: "Add item"), systemImage: "plus.circle.fill")
                        }
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onLogPurchase()
                        } label: {
                            Label(String(localized: "Log a spend"), systemImage: "dollarsign.circle.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(BrandSymbolFont.symbol(20, weight: .semibold))
                            .foregroundStyle(.gsBrandPrimary)
                            .symbolRenderingMode(.monochrome)
                    }
                    .accessibilityLabel(String(localized: "Add or log spend"))
                    .accessibilityHint(String(localized: "Double tap to choose add item or log a spend"))
                }
            }
            .refreshable {
                await dashboardVM.loadData(forceRefresh: true, authService: authService)
                await financeVM.loadData(forceRefresh: true)
                await pantryVM.loadItems(forceRefresh: true)
                await profileVM.loadData(forceRefresh: true)
                await shoppingListsVM.loadLists(forceRefresh: true)
                lastFeedSyncedAt = .now
            }
            .task {
                async let dash: Void = dashboardVM.loadData(authService: authService)
                async let fin: Void = financeVM.loadData()
                async let pant: Void = pantryVM.loadItems()
                async let prof: Void = profileVM.loadData()
                async let shop: Void = shoppingListsVM.loadLists()
                _ = await (dash, fin, pant, prof, shop)
                lastFeedSyncedAt = .now
            }
            .onChange(of: dashboardVM.totalPantryItems) { _, count in
                if count >= 2 { coldStartDismissed = true }
            }
            .confirmationDialog(
                "Record outcome for \(pantryVM.itemToRemove?.name ?? "this item")?",
                isPresented: $pantryVM.showRemovalPrompt,
                titleVisibility: .visible
            ) {
                Button("Used") {
                    Task { await pantryVM.confirmUsed() }
                }
                Button("Remove from list", role: .destructive) {
                    Task { await pantryVM.confirmRemoveFromList() }
                }
                Button("Expired", role: .destructive) {
                    pantryVM.beginExpiredRemoval()
                }
                Button("Waste", role: .destructive) {
                    pantryVM.beginWasteRemoval()
                }
                Button("Cancel", role: .cancel) {
                    pantryVM.cancelRemovalFlow()
                }
            }
            .alert("Estimated cost (optional)", isPresented: $pantryVM.showWasteCostPrompt) {
                TextField("Amount", text: $pantryVM.wasteCostText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    Task { await pantryVM.saveWasteEvent() }
                }
                Button("Skip") {
                    Task { await pantryVM.saveWasteEvent(skipCost: true) }
                }
                Button("Cancel", role: .cancel) {
                    pantryVM.cancelRemovalFlow()
                }
            }
            .sheet(isPresented: $showDashboardPantryReview) {
                PantryReviewView(viewModel: PantryReviewViewModel(
                    repository: dashboardVM.pantryRepository,
                    householdId: dashboardVM.householdId,
                    userId: pantryVM.userId,
                    staleItems: dashboardVM.staleItems
                ))
            }
            .sheet(item: $pantryVM.itemToEdit) { item in
                AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                    repository: pantryVM.repository,
                    householdId: pantryVM.householdId,
                    userId: pantryVM.userId,
                    userRole: pantryVM.userRole,
                    existingItem: item
                ))
            }
            .sheet(isPresented: $showReviewSheet, onDismiss: {
                Task { await pantryVM.loadItems(forceRefresh: true) }
            }) {
                PantryReviewView(viewModel: PantryReviewViewModel(
                    repository: pantryVM.repository,
                    householdId: pantryVM.householdId,
                    userId: pantryVM.userId,
                    staleItems: pantryVM.staleItemsForReview
                ))
            }
            .sheet(isPresented: $showExpiryCalendar) {
                NavigationStack {
                    ExpiryCalendarView(
                        items: dashboardVM.expiringItems,
                        householdId: pantryVM.householdId,
                        userId: pantryVM.userId,
                        userRole: pantryVM.userRole
                    )
                        .navigationTitle("Expiring")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showExpiryCalendar = false
                                }
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                }
            }
            .tint(.gsBrandPrimary)
        }
    }

    private var todayDashboardContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.homeChromeVerticalSpacing) {
                HomeDashboardChrome(
                    dashboardVM: dashboardVM,
                    financeVM: financeVM,
                    profileVM: profileVM,
                    shoppingListsVM: shoppingListsVM,
                    greetingTitle: greetingTitle,
                    lowStockSampleNames: lowStockSampleNames,
                    onNavigateToInsights: onNavigateToInsights,
                    onNavigateToShopping: onNavigateToShopping,
                    onOpenPantryTab: onOpenPantryTab,
                    onOpenExpiryCalendar: { showExpiryCalendar = true },
                    onAddItem: { pantryVM.showAddSheet = true },
                    onLogPurchase: onLogPurchase
                )

                if dashboardVM.isAdmin && dashboardVM.pendingApprovalsCount > 0 {
                    PendingApprovalsCard(count: dashboardVM.pendingApprovalsCount) {
                        onReviewPendingApprovals()
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                if showColdStartGuide {
                    ColdStartGuideCard(
                        pantryItemCount: dashboardVM.totalPantryItems,
                        onGoShop: onNavigateToShopping,
                        onDismiss: { coldStartDismissed = true }
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    if let synced = lastFeedSyncedAt {
                        Text(FeedSyncFormatter.lastUpdatedLabel(at: synced))
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary.opacity(0.9))
                            .accessibilityLabel("Feed data \(FeedSyncFormatter.lastUpdatedLabel(at: synced))")
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Text("Household activity")
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(.gsTextSecondary)
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .padding(.top, AppSpacing.smallSpacing)
                    .padding(.horizontal, AppSpacing.screenPadding)

                FeedActivityCard(
                    timestamp: "Today",
                    healthScoreColumn: nil,
                    chipText: "New",
                    chipStyle: .neutral,
                    title: additionsTitleLine,
                    subtitle: additionsSubtitleLine,
                    accessibilitySummary: "\(additionsTitleLine). \(additionsSubtitleLine). Double tap to open pantry."
                ) {
                    if newestItems.isEmpty {
                        pantryVM.showAddSheet = true
                    } else {
                        onOpenPantryTab(nil)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

            }
            .padding(.top, AppSpacing.smallSpacing)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
    }

    private var lowStockSampleNames: [String] {
        pantryVM.approvedItems
            .filter { $0.state == .lowStock }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(3)
            .map(\.name)
    }
}

// MARK: - Feed card chrome

private enum FeedChipStyle {
    case teal
    case purple
    case warning
    case neutral

    var foregroundColor: Color {
        switch self {
        case .teal: return .gsBrandPrimary
        case .purple: return BrandPalette.Exploration.softPlum
        case .warning: return .gsWarning
        case .neutral: return .gsTextSecondary
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.14)
    }
}

private struct FeedActivityCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let timestamp: String
    var healthScoreColumn: (score: Int, caption: String)?
    let chipText: String
    let chipStyle: FeedChipStyle
    let title: String
    let subtitle: String
    let accessibilitySummary: String
    let action: () -> Void

    private var subtitleLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? 8 : 3
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack(alignment: .top, spacing: AppSpacing.mediumSpacing) {
                    VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                        Text(timestamp)
                            .font(BrandFont.semiBold(13))
                            .foregroundStyle(.gsTextSecondary)
                            .textCase(.uppercase)
                            .tracking(1.0)
                        if let health = healthScoreColumn {
                            Text("\(health.score)")
                                .font(BrandFont.bold(28))
                                .foregroundStyle(.gsTextPrimary)
                                .contentTransition(.numericText())
                            Text(health.caption)
                                .font(BrandFont.medium(13))
                                .foregroundStyle(.gsTextSecondary)
                                .textCase(.lowercase)
                        }
                    }
                    .frame(minWidth: 56, alignment: .leading)

                    Spacer(minLength: AppSpacing.smallSpacing)

                    Text(chipText)
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(chipStyle.foregroundColor)
                        .padding(.horizontal, AppSpacing.mediumSpacing)
                        .padding(.vertical, AppSpacing.filterChipInnerSpacing)
                        .background(
                            Capsule(style: .continuous)
                                .fill(chipStyle.backgroundColor)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(chipStyle.foregroundColor.opacity(0.22), lineWidth: 0.5)
                        )
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(BrandFont.semiBold(18))
                    .foregroundStyle(.gsTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(BrandFont.regular(16))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius, style: .continuous)
                    .fill(.gsSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius, style: .continuous)
                    .strokeBorder(Color.gsBorder.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.045), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.99))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Double tap to act on this update")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Cold start (empty pantry)

private struct ColdStartGuideCard: View {
    let pantryItemCount: Int
    let onGoShop: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("Welcome to your feed")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Spacer(minLength: 0)
                Button("Dismiss", action: onDismiss)
                    .font(BrandFont.semiBold(16))
                    .foregroundStyle(.gsBrandPrimary)
            }
            Text("Start with a shopping list. Your pantry fills itself after you shop.")
                .font(BrandFont.regular(16))
                .foregroundStyle(.gsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onGoShop) {
                Label("Create a shopping list", systemImage: "cart.fill")
                    .font(BrandFont.semiBold(17))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            Text("You can also add items, log expenses, or manage your household from the tabs below.")
                .font(BrandFont.regular(14))
                .foregroundStyle(.gsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
    }
}
