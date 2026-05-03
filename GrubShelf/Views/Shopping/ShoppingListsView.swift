import SwiftUI

struct ShoppingListsView: View {
    @State private var viewModel: ShoppingListsViewModel
    let financeVM: FinanceViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showEmptyState = false
    @State private var showHomeScreenWidgetGuide = false
    @State private var listToDelete: ShoppingList?
    @State private var showDoneItems = false
    @FocusState private var isActiveAddFieldFocused: Bool

    init(viewModel: ShoppingListsViewModel, financeVM: FinanceViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.financeVM = financeVM
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if !viewModel.hasLoaded {
                    ShoppingSkeletonView()
                } else if viewModel.lists.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .navigationTitle("Shop")
            .toolbar {
                if viewModel.hasLoaded {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showHomeScreenWidgetGuide = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(BrandSymbolFont.symbol(17))
                        }
                        .accessibilityLabel("Add shopping list to Home Screen")
                        .accessibilityHint("Shows steps to add the \(BrandCopy.displayName) widget")
                    }
                }
                if viewModel.hasLoaded && !viewModel.lists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        PrimaryPlusToolbarButton(
                            accessibilityLabel: "New shopping list",
                            accessibilityHint: "Double tap to create a new shopping list"
                        ) {
                            viewModel.showCreateSheet = true
                        }
                    }
                }
            }
            .background(.gsBackground)
            .refreshable {
                await viewModel.loadLists(forceRefresh: true)
                await viewModel.loadActiveListItems()
            }
            .task {
                await viewModel.loadLists()
                await viewModel.loadActiveListItems()
                viewModel.startObserving()
            }
            .onDisappear {
                viewModel.stopObserving()
            }
            .onReceive(NotificationCenter.default.publisher(for: .grubShelfShoppingWidgetToggleQueueFlushed)) { _ in
                Task {
                    await viewModel.loadLists(forceRefresh: true)
                    await viewModel.loadActiveListItems()
                }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateShoppingListSheet(viewModel: viewModel) { list in
                    navigationPath.append(list)
                }
            }
            .sheet(isPresented: $showHomeScreenWidgetGuide) {
                NavigationStack {
                    HomeScreenWidgetGuideView()
                }
            }
            .alert("Something went wrong", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Delete list?", isPresented: .init(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let list = listToDelete {
                        Task { await viewModel.deleteList(list) }
                    }
                }
                Button("Cancel", role: .cancel) { listToDelete = nil }
            } message: {
                Text("This will permanently delete \"\(listToDelete?.name ?? "")\" and all its items.")
            }
            .navigationDestination(for: ShoppingList.self) { list in
                ShoppingListDetailView(
                    list: list,
                    householdId: viewModel.householdId,
                    userId: viewModel.userId,
                    currencyCode: financeVM.currencyCode
                )
            }
            .tint(.gsBrandPrimary)
        }
    }

    // MARK: - Empty State (#2)

    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .center, spacing: AppSpacing.sectionSpacing) {
                Spacer(minLength: AppSpacing.scrollVerticalBreathingRoom)

                TabEmptyStateHero(
                    systemName: "cart",
                    symbolFontSize: EmptyStateMetrics.tabHeroSymbolSizeCompact,
                    symbolWeight: .bold,
                    imageAsset: "onboarding-shopping"
                )
                .opacity(showEmptyState ? 1 : 0)
                .scaleEffect(showEmptyState ? 1 : 0.92)

                EmptyStateCopyCard(
                    title: String(localized: "No lists yet"),
                    subtitle: String(localized: "Start a list when you’re ready—we’ll keep it here.")
                )
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 12)

                EmptyStateTealCTAButton(
                    title: String(localized: "New list"),
                    systemImage: "cart.badge.plus"
                ) {
                    viewModel.showCreateSheet = true
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 12)

                Spacer(minLength: AppSpacing.scrollVerticalBreathingRoom)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .animation(.spring(response: 0.45, dampingFraction: 0.86).delay(0.12), value: showEmptyState)
            .onAppear { showEmptyState = true }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.rowSpacing) {
                // Active list expanded inline
                if let activeList = viewModel.activeList {
                    activeListExpandedCard(activeList)
                }

                // Other lists section
                if !viewModel.otherLists.isEmpty {
                    otherListsSection
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.compactGap)
            .padding(.bottom, AppSpacing.scrollVerticalBreathingRoom)
        }
    }

    // MARK: - Active List Expanded Card

    private func activeListExpandedCard(_ list: ShoppingList) -> some View {
        let counts = viewModel.listItemCounts[list.listId] ?? (pending: 0, completed: 0)
        let total = counts.pending + counts.completed
        let progress: Double = total > 0 ? Double(counts.completed) / Double(total) : 0

        return VStack(spacing: 0) {
            // Header
            Button {
                navigationPath.append(list)
            } label: {
                HStack(spacing: AppSpacing.smallSpacing) {
                    Text("🛒")
                        .font(.system(size: 20))
                    Text(list.name)
                        .font(BrandFont.bold(18))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(counts.completed)/\(total)")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.gsTextSecondary)
                    Image(systemName: "chevron.right")
                        .font(BrandSymbolFont.symbol(13, weight: .semibold))
                        .foregroundStyle(.gsTextSecondary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.smallSpacing)
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geo in
                Capsule()
                    .fill(Color.gsSurface.opacity(0.6))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.gsBrandPrimary)
                            .frame(width: max(0, geo.size.width * progress), height: 3)
                            .animation(.easeOut(duration: 0.35), value: progress)
                    }
            }
            .frame(height: 3)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.rowSpacing)

            // Inline add item row (top, so items appear beneath)
            HStack(spacing: AppSpacing.rowSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.gsBrandPrimary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(BrandSymbolFont.symbol(13, weight: .bold))
                        .foregroundStyle(.gsBrandPrimary)
                }

                TextField("Add an item...", text: $viewModel.activeListNewItemName)
                    .font(BrandFont.regular(16))
                    .foregroundStyle(.gsTextPrimary)
                    .focused($isActiveAddFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        Task { await viewModel.addItemToActiveList() }
                    }
                    .onChange(of: viewModel.activeListNewItemName) {
                        viewModel.searchActiveCatalog()
                    }

                if !viewModel.activeListNewItemName.isEmpty {
                    Button {
                        Task { await viewModel.addItemToActiveList() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(BrandSymbolFont.symbol(24))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                    .buttonStyle(.plain)
                }

                if isActiveAddFieldFocused {
                    Button("Done") {
                        isActiveAddFieldFocused = false
                    }
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsBrandPrimary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.rowSpacing)

            // Catalog suggestions (right below search)
            if !viewModel.activeCatalogSuggestions.isEmpty {
                VStack(spacing: 0) {
                    Divider().padding(.horizontal, AppSpacing.cardPadding)
                    ForEach(viewModel.activeCatalogSuggestions, id: \.name) { item in
                        Button {
                            Task { await viewModel.addActiveCatalogItem(item) }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Text(ItemIconMapper.emoji(for: item.name, category: item.defaultCategory))
                                    .font(.system(size: 16))
                                Text(item.name)
                                    .font(BrandFont.regular(15))
                                    .foregroundStyle(.gsTextPrimary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(BrandSymbolFont.symbol(16))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.smallSpacing)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Pending items (beneath search bar)
            ForEach(viewModel.activeListPendingItems) { item in
                ShoppingItemRow(item: item) {
                    Task { await viewModel.toggleActiveItem(item) }
                }
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
            }

            // Done section
            if !viewModel.activeListCompletedItems.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showDoneItems.toggle()
                    }
                } label: {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Image(systemName: showDoneItems ? "chevron.down" : "chevron.right")
                            .font(BrandSymbolFont.symbol(12, weight: .semibold))
                            .foregroundStyle(.gsTextSecondary)
                        Text("Done (\(viewModel.activeListCompletedItems.count))")
                            .font(BrandFont.semiBold(14))
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.smallSpacing)
                }
                .buttonStyle(.plain)

                if showDoneItems {
                    ForEach(viewModel.activeListCompletedItems) { item in
                        ShoppingItemRow(item: item) {
                            Task { await viewModel.toggleActiveItem(item) }
                        }
                        .opacity(0.55)
                        .padding(.horizontal, AppSpacing.smallSpacing)
                        .padding(.vertical, AppSpacing.compactGap)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(Color.gsSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(Color.gsBorder.opacity(0.45), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .task {
            await viewModel.loadActiveListItems()
        }
        .contextMenu {
            Button(role: .destructive) {
                listToDelete = list
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Other Lists Section

    private var otherListsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
            Text("Other Lists")
                .font(BrandFont.semiBold(14))
                .foregroundStyle(.gsTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.top, AppSpacing.rowSpacing)

            ForEach(viewModel.otherLists) { list in
                Button {
                    navigationPath.append(list)
                } label: {
                    ShoppingListCard(
                        list: list,
                        counts: viewModel.listItemCounts[list.listId]
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        listToDelete = list
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}
