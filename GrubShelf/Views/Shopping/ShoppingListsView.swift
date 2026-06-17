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
                if viewModel.hasLoaded && !viewModel.lists.isEmpty && viewModel.canCreateShoppingList {
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
            .alert("Reject item?", isPresented: $viewModel.showActiveRejectReasonPrompt) {
                TextField("Reason (optional)", text: $viewModel.activeRejectReasonText)
                Button("Reject", role: .destructive) {
                    Task { await viewModel.confirmRejectActiveItem() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRejectActiveItem()
                }
            } message: {
                if let item = viewModel.activeItemToReject {
                    Text("Reject \"\(item.name)\"? The member will see your reason if provided.")
                }
            }
            .navigationDestination(for: ShoppingList.self) { list in
                ShoppingListDetailView(
                    list: list,
                    householdId: viewModel.householdId,
                    userId: viewModel.userId,
                    userRole: viewModel.userRole,
                    currencyCode: financeVM.currencyCode,
                    financeVM: financeVM
                )
            }
            .tint(.gsBrandPrimary)
        }
    }

    // MARK: - Empty State (#2)

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()

            // Large hero icon with background circle
            ZStack {
                Circle()
                    .fill(.gsBrandPrimary.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "cart.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.gsBrandPrimary)
                    .symbolRenderingMode(.hierarchical)
            }

            // Title with better typography
            VStack(spacing: 8) {
                Text("No Shopping Lists")
                    .font(BrandFont.semiBold(26))
                    .foregroundStyle(.gsTextPrimary)

                Text(viewModel.canCreateShoppingList
                     ? "Create your first list to get started"
                     : "Ask your household admin to create a list")
                    .font(BrandFont.regular(16))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Feature hints - more compact (only for users who can create)
            if viewModel.canCreateShoppingList {
                VStack(spacing: 12) {
                    ShoppingEmptyFeatureRow(
                        icon: "list.bullet.clipboard",
                        text: "Organize by store or category"
                    )
                    ShoppingEmptyFeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Sync with pantry inventory"
                    )
                    ShoppingEmptyFeatureRow(
                        icon: "person.2.fill",
                        text: "Share with family members"
                    )
                }
                .padding(.horizontal, AppSpacing.screenPadding * 2)
            }

            // CTA button - compact (only if user can create)
            if viewModel.canCreateShoppingList {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create Your First List")
                            .font(BrandFont.semiBold(17))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(.gsBrandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .gsBrandPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
    }

    // Helper view for feature rows
    private struct ShoppingEmptyFeatureRow: View {
        let icon: String
        let text: String

        var body: some View {
            HStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.gsBrandPrimary)
                    .frame(width: 24)

                Text(text)
                    .font(BrandFont.medium(15))
                    .foregroundStyle(.gsTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                    .autocorrectionDisabled(true)
                    .focused($isActiveAddFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !viewModel.activeCatalogSuggestionsVisible else { return }
                        Task { await viewModel.addItemToActiveList() }
                    }
                    .onChange(of: viewModel.activeListNewItemName) {
                        viewModel.searchActiveCatalog()
                        viewModel.checkActivePantryDuplicate(name: viewModel.activeListNewItemName)
                    }

                if !viewModel.activeListNewItemName.isEmpty, !viewModel.activeCatalogSuggestionsVisible {
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

            if let warning = viewModel.activePantryWarning {
                HStack(spacing: AppSpacing.denseSpacing) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.gsWarning)
                        .font(BrandSymbolFont.symbol(12))
                    Text(warning)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.compactGap)
            }

            // Catalog suggestions (right below search)
            if !viewModel.activeCatalogSuggestions.isEmpty {
                VStack(spacing: 0) {
                    Text("Tap a product below. Use + and − on each item to change quantity.")
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.top, AppSpacing.smallSpacing)
                    Divider().padding(.horizontal, AppSpacing.cardPadding)
                    ForEach(viewModel.activeCatalogSuggestions) { item in
                        Button {
                            Task { await viewModel.addActiveCatalogItem(item) }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Text(ItemIconMapper.emoji(for: item.name, category: item.defaultCategory))
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                    Text(item.name)
                                        .font(BrandFont.regular(15))
                                        .foregroundStyle(.gsTextPrimary)
                                    if let pantryHint = viewModel.activePantrySuggestionSubtitle(for: item) {
                                        Text(pantryHint)
                                            .font(BrandFont.regular(13))
                                            .foregroundStyle(.gsWarning)
                                    }
                                }
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

            if viewModel.isAdmin && !viewModel.activeListAwaitingApproval.isEmpty {
                PendingApprovalShoppingSection(
                    items: viewModel.activeListAwaitingApproval,
                    isAdmin: true,
                    onApprove: { item in Task { await viewModel.approveActiveItem(item) } },
                    onReject: { item in viewModel.beginRejectActiveItem(item) }
                )
                Divider().padding(.horizontal, AppSpacing.cardPadding)
            } else if !viewModel.isAdmin && !viewModel.activeListAwaitingApproval.isEmpty {
                PendingApprovalShoppingSection(
                    items: viewModel.activeListAwaitingApproval.filter { $0.createdBy == viewModel.userId },
                    isAdmin: false
                )
                Divider().padding(.horizontal, AppSpacing.cardPadding)
            }

            // Pending items (beneath search bar)
            ForEach(viewModel.activeListPendingItems) { item in
                ShoppingItemRow(
                    item: item,
                    canToggle: true,
                    isAdjustingQuantity: viewModel.inflightItemIds.contains(item.itemId),
                    onToggle: { Task { await viewModel.toggleActiveItem(item) } },
                    onIncrementQuantity: { Task { await viewModel.adjustActiveQuantity(itemId: item.itemId, delta: 1) } },
                    onDecrementQuantity: { Task { await viewModel.adjustActiveQuantity(itemId: item.itemId, delta: -1) } }
                )
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
            }

            // Inline transfer CTA — only after every item on the list is checked off.
            if viewModel.hasActiveTransferableItems {
                inlineTransferBanner(list: list)
            } else if list.transferred {
                inlineTransferredBadge()
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
            if viewModel.canDeleteShoppingList {
                Button(role: .destructive) {
                    listToDelete = list
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $viewModel.showActiveTransferSheet, onDismiss: {
            Task {
                await viewModel.refreshAfterActiveTransfer()
                await financeVM.loadData(forceRefresh: true)
            }
        }) {
            activeTransferSheet(list: list)
        }
    }

    // MARK: - Inline transfer CTA

    private func inlineTransferBanner(list: ShoppingList) -> some View {
        let count = viewModel.transferableActiveListItems.count
        let title = "Move \(count) item\(count == 1 ? "" : "s") to pantry"
        let subtitle = viewModel.allActiveListItemsCompleted
            ? "Everything's checked off — add them to your pantry."
            : "Tap to move checked items to your pantry."

        return Button {
            Task { await viewModel.prepareActiveTransfer() }
        } label: {
            HStack(spacing: AppSpacing.rowSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.gsSuccess.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(BrandSymbolFont.symbol(18, weight: .semibold))
                        .foregroundStyle(.gsSuccess)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.semiBold(15))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.smallSpacing)

                Text("Transfer")
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.smallSpacing)
                    .padding(.vertical, AppSpacing.compactGap)
                    .background(Color.gsSuccess, in: Capsule())
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.smallSpacing)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Opens the transfer-to-pantry sheet")
    }

    private func inlineTransferredBadge() -> some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            Image(systemName: "checkmark.seal.fill")
                .font(BrandSymbolFont.symbol(14, weight: .semibold))
                .foregroundStyle(.gsSuccess)
            Text("Transferred to pantry")
                .font(BrandFont.medium(13))
                .foregroundStyle(.gsTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.smallSpacing)
    }

    private func activeTransferSheet(list: ShoppingList) -> some View {
        TransferFlowSheet(
            transferableItems: viewModel.transferableActiveListItems,
            pantryItems: viewModel.activeListPantryItems,
            householdId: list.householdId,
            userId: viewModel.userId,
            listId: list.listId,
            currencyCode: financeVM.currencyCode
        )
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
                    if viewModel.canDeleteShoppingList {
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
}
