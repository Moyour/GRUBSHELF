import SwiftUI

struct ShoppingListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ShoppingListViewModel
    @FocusState private var addFieldFocused: Bool
    @State private var itemToDelete: ShoppingItem?
    @State private var filterText: String = ""

    private let list: ShoppingList
    private let userId: UUID
    private let currencyCode: String
    private let financeVM: FinanceViewModel?

    init(
        list: ShoppingList,
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member,
        currencyCode: String = "GBP",
        financeVM: FinanceViewModel? = nil
    ) {
        self.list = list
        self.userId = userId
        self.currencyCode = currencyCode
        self.financeVM = financeVM
        let vm = ShoppingListViewModel(
            repository: SupabaseShoppingRepository(),
            householdId: householdId,
            userId: userId,
            userRole: userRole,
            listId: list.listId
        )
        // Initial transferred state from list; refreshed from item-level flags after load
        vm.listTransferred = list.transferred
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        List {
            // MARK: - Transfer Banner (#6 — card style)
            if viewModel.hasTransferableItems {
                Section {
                    HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(BrandSymbolFont.symbol(17, weight: .semibold))
                            .foregroundStyle(.gsSuccess)
                            .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)

                        Text(viewModel.allItemsCompleted
                             ? "All items checked off — ready for pantry"
                             : "\(viewModel.transferableItems.count) checked item\(viewModel.transferableItems.count == 1 ? "" : "s") ready for pantry")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: AppSpacing.smallSpacing)

                        Button("Transfer") {
                            viewModel.showTransferSheet = true
                        }
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsSuccess)
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "All items checked off. Transfer \(viewModel.transferableItems.count) items to pantry"
                    )
                    .accessibilityHint("Double tap Transfer to move items to your pantry")
                }
                .listRowInsets(AppSpacing.listRowCardInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if viewModel.listTransferred {
                Section {
                    HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(BrandSymbolFont.symbol(17, weight: .semibold))
                            .foregroundStyle(.gsSuccess)
                            .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)

                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            Text("Transferred to pantry")
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextPrimary)
                            Text("This list’s items are in your inventory.")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Transferred to pantry. This list’s items are in your inventory.")
                }
                .listRowInsets(AppSpacing.listRowCardInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            // MARK: - Add Item Section
            Section {
                VStack(spacing: 0) {
                    InlineSearchFieldRow(
                        text: $viewModel.newItemName,
                        placeholder: "Search & add item…",
                        submitLabel: .done,
                        autocorrectionDisabled: true,
                        showClearButton: true,
                        accessibilityLabel: "Search and add item",
                        onSubmit: {
                            // When catalog suggestions are visible, "Done" just
                            // dismisses the keyboard — user should tap a suggestion
                            // or the explicit "Add" button instead.
                            guard viewModel.catalogSuggestions.isEmpty else { return }
                            let captured = viewModel.newItemName
                            Task {
                                await viewModel.addItem(overrideName: captured)
                                viewModel.clearSuggestions()
                            }
                        },
                        onClear: { viewModel.clearSuggestions() },
                        isFocused: $addFieldFocused
                    )

                    if let warning = viewModel.duplicateWarning {
                        HStack(alignment: .top, spacing: AppSpacing.smallSpacing) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.gsWarning)
                                .font(BrandSymbolFont.symbol(16))
                            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                Text("Already in pantry")
                                    .font(BrandFont.semiBold(14))
                                    .foregroundStyle(.gsTextPrimary)
                                Text(warning)
                                    .font(BrandFont.regular(13))
                                    .foregroundStyle(.gsTextSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(AppSpacing.rowSpacing)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous)
                                .fill(Color.gsWarningSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous)
                                .stroke(Color.gsWarning.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.top, AppSpacing.compactGap)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Already in pantry. \(warning)")
                    }

                    if viewModel.isSearchingCatalog {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching…")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        .padding(.top, AppSpacing.smallSpacing)
                    }

                    // Catalog suggestions — shown first so they're the primary action.
                    // Each row is keyed by catalog UUID so SwiftUI never
                    // confuses one item for another during search updates.
                    ForEach(viewModel.catalogSuggestions) { item in
                        Button {
                            // Freeze search so suggestions can't shift mid-tap.
                            viewModel.cancelPendingSearch()
                            let chosen = item
                            Task {
                                await viewModel.addCatalogItem(chosen)
                            }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gsBrandPrimary)
                                    .font(BrandSymbolFont.symbol(20))

                                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                    Text(item.name)
                                        .font(BrandFont.medium(17))
                                        .foregroundStyle(.gsTextPrimary)
                                    if let pantryHint = viewModel.pantrySuggestionSubtitle(for: item) {
                                        HStack(spacing: AppSpacing.denseSpacing) {
                                            Image(systemName: "archivebox.fill")
                                                .font(BrandSymbolFont.symbol(11))
                                            Text(pantryHint)
                                        }
                                        .font(BrandFont.regular(14))
                                        .foregroundStyle(.gsWarning)
                                    }
                                    Text("\(item.defaultCategory) · \(item.defaultUnit.displayName)")
                                        .font(BrandFont.regular(14))
                                        .foregroundStyle(.gsTextSecondary)
                                }

                                Spacer()
                            }
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }

                    // Free-text add — visible when user has typed 2+ chars.
                    // Visually distinct from catalog rows (outline icon, italic label).
                    if !viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !viewModel.isSearchingCatalog
                        && viewModel.newItemName.count >= 2 {

                        if !viewModel.catalogSuggestions.isEmpty {
                            Divider()
                                .padding(.vertical, AppSpacing.smallSpacing)
                        }

                        Button {
                            let captured = viewModel.newItemName
                            viewModel.cancelPendingSearch()
                            Task {
                                await viewModel.addItem(overrideName: captured)
                                viewModel.clearSuggestions()
                            }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Image(systemName: "text.badge.plus")
                                    .foregroundStyle(.gsTextSecondary)
                                    .font(BrandSymbolFont.symbol(18))
                                Text("Add \"\(viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines))\" as custom item")
                                    .font(BrandFont.regular(15))
                                    .foregroundStyle(.gsTextSecondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.inlineSearchCardVerticalPadding)
                .dashboardCardSurface()
            } header: {
                shoppingDetailSectionHeader(title: "Add items", count: nil, emphasis: .standard)
            }
            .listRowInsets(AppSpacing.listRowCardInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if !viewModel.awaitingApprovalItems.isEmpty {
                Section {
                    ForEach(viewModel.awaitingApprovalItems) { item in
                        PendingApprovalItemCard(
                            title: item.name,
                            subtitle: PendingApprovalCopy.shoppingSubtitle,
                            showsActions: viewModel.isAdmin,
                            onApprove: { Task { await viewModel.approveItem(item) } },
                            onReject: { viewModel.beginRejectItem(item) }
                        )
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    shoppingDetailSectionHeader(
                        title: "Pending approval",
                        count: viewModel.awaitingApprovalItems.count,
                        emphasis: .standard
                    )
                }
            }

            // MARK: - To buy
            Section {
                ForEach(filteredPending) { item in
                    ShoppingItemRow(
                        item: item,
                        canToggle: true,
                        isAdjustingQuantity: viewModel.inflightItemIds.contains(item.itemId),
                        pantryQuantityHint: pantryHint(for: item),
                        onToggle: { Task { await viewModel.toggleComplete(item) } },
                        onIncrementQuantity: { Task { await viewModel.adjustQuantity(itemId: item.itemId, delta: 1) } },
                        onDecrementQuantity: { Task { await viewModel.adjustQuantity(itemId: item.itemId, delta: -1) } }
                    )
                    .listRowInsets(AppSpacing.listRowCardInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task { await viewModel.quickMoveToPantry(item) }
                        } label: {
                            Label("Pantry", systemImage: "archivebox.fill")
                        }
                        .tint(.gsBrandPrimary)
                        .disabled(viewModel.inflightItemIds.contains(item.itemId))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.isAdmin {
                            Button(role: .destructive) {
                                itemToDelete = item
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                shoppingDetailSectionHeader(
                    title: "To buy",
                    count: filteredPending.count,
                    emphasis: .standard
                )
            }

            // MARK: - Done
            if !filteredCompleted.isEmpty {
                Section {
                    ForEach(filteredCompleted) { item in
                        ShoppingItemRow(item: item, canToggle: true) {
                            Task { await viewModel.toggleComplete(item) }
                        }
                        .opacity(item.transferred ? 0.35 : 0.55)
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !item.transferred {
                                Button {
                                    Task { await viewModel.quickMoveToPantry(item) }
                                } label: {
                                    Label("Pantry", systemImage: "archivebox.fill")
                                }
                                .tint(.gsBrandPrimary)
                                .disabled(viewModel.inflightItemIds.contains(item.itemId))
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.isAdmin {
                                Button(role: .destructive) {
                                    itemToDelete = item
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    shoppingDetailSectionHeader(
                        title: "Done",
                        count: filteredCompleted.count,
                        emphasis: .muted
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
        .searchable(text: $filterText, prompt: "Filter items…")
        .refreshable {
            await viewModel.loadItems()
        }
        .navigationTitle(list.name)
        .background(.gsBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if ShoppingListWidgetPreferences.pinnedListId() == list.listId {
                        Button("Clear Home Screen widget pin", role: .destructive) {
                            ShoppingListWidgetPreferences.clearPinnedList()
                            Task { await refreshShoppingListWidgetSnapshot() }
                        }
                    } else {
                        Button {
                            ShoppingListWidgetPreferences.setPinnedList(list.listId)
                            Task { await refreshShoppingListWidgetSnapshot() }
                        } label: {
                            Label("Pin for Home Screen widget", systemImage: "pin")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(BrandSymbolFont.symbol(17, weight: .semibold))
                }
                .accessibilityLabel("List options")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    addFieldFocused = false
                    dismiss()
                }
                .font(BrandFont.semiBold(17))
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Task { await viewModel.markAllComplete() }
                } label: {
                    Label("Complete All", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.pendingItems.isEmpty)

                Spacer()

                Button {
                    viewModel.showTransferSheet = true
                } label: {
                    Label("Transfer to Pantry", systemImage: "arrow.right.circle")
                }
                .disabled(!viewModel.hasTransferableItems)
            }
        }
        .sheet(isPresented: $viewModel.showTransferSheet, onDismiss: {
            Task {
                await viewModel.refreshTransferredStatus()
                await financeVM?.loadData(forceRefresh: true)
            }
        }) {
            TransferFlowSheet(
                transferableItems: viewModel.transferableItems,
                pantryItems: viewModel.pantryItems,
                householdId: list.householdId,
                userId: userId,
                listId: list.listId,
                currencyCode: currencyCode
            )
        }
        .sheet(isPresented: $viewModel.showCatalogSearch) {
            CatalogSearchSheet(
                catalogRepository: SupabaseGroceryCatalogRepository(),
                onSelect: { catalogItem in
                    Task { await viewModel.addCatalogItem(catalogItem) }
                },
                onAddManually: {
                    addFieldFocused = true
                }
            )
        }
        .alert("Delete item?", isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { await viewModel.deleteItem(item) }
                }
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("Remove \"\(itemToDelete?.name ?? "")\" from this list?")
        }
        .confirmationDialog(
            "This item is already in your pantry",
            isPresented: $viewModel.showDuplicateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Add Anyway") {
                Task { await viewModel.confirmAddDespiteDuplicate() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDuplicateConfirmation()
            }
        } message: {
            if let match = viewModel.pantryMatchForNewItem {
                Text(ShoppingListAddBehavior.pantryMatchMessageWithTime(for: match))
            }
        }
        .alert("Reject item?", isPresented: $viewModel.showRejectReasonPrompt) {
            TextField("Reason (optional)", text: $viewModel.rejectReasonText)
            Button("Reject", role: .destructive) {
                Task { await viewModel.confirmRejectItem() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelRejectItem()
            }
        } message: {
            if let item = viewModel.itemToReject {
                Text("Reject \"\(item.name)\"? The member will see your reason if provided.")
            }
        }
        .onChange(of: viewModel.newItemName) {
            viewModel.searchCatalog()
            viewModel.checkDuplicate(name: viewModel.newItemName)
        }
        .task {
            await viewModel.loadItems()
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .onReceive(NotificationCenter.default.publisher(for: .grubShelfShoppingWidgetToggleQueueFlushed)) { _ in
            Task { await viewModel.loadItems() }
        }
    }

    private var filteredPending: [ShoppingItem] {
        let items = viewModel.pendingItems
        guard !filterText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private var filteredCompleted: [ShoppingItem] {
        let items = viewModel.completedItems
        guard !filterText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private func refreshShoppingListWidgetSnapshot() async {
        let hid = list.householdId
        let listRepo = SupabaseShoppingListRepository()
        let shopRepo = SupabaseShoppingRepository()
        guard let lists = try? await listRepo.fetchAll(householdId: hid),
              let items = try? await shopRepo.fetchAll(householdId: hid) else { return }
        await MainActor.run {
            ShoppingListWidgetDataStore.shared.sync(lists: lists, items: items)
        }
    }

    private enum ShoppingDetailSectionEmphasis {
        case standard
        case muted
    }

    @ViewBuilder
    private func shoppingDetailSectionHeader(
        title: String,
        count: Int?,
        emphasis: ShoppingDetailSectionEmphasis
    ) -> some View {
        let color: Color = emphasis == .muted ? .gsTextSecondary.opacity(0.72) : .gsTextSecondary
        HStack {
            Text(title)
                .font(BrandFont.semiBold(15))
            Spacer()
            if let count {
                Text("\(count)")
                    .font(BrandFont.regular(14))
            }
        }
        .foregroundStyle(color)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(accessibilityLabelForSection(title: title, count: count))
    }

    private func pantryHint(for item: ShoppingItem) -> String? {
        guard let match = ShoppingListAddBehavior.pantryMatch(in: viewModel.pantryItems, name: item.name) else { return nil }
        return "\(match.quantity.formatted()) in pantry"
    }

    private func accessibilityLabelForSection(title: String, count: Int?) -> String {
        if let count {
            return "\(title), \(count) items"
        }
        return title
    }
}
