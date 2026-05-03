import SwiftUI

struct ShoppingListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ShoppingListViewModel
    @FocusState private var addFieldFocused: Bool
    @State private var itemToDelete: ShoppingItem?

    private let list: ShoppingList
    private let currencyCode: String

    init(list: ShoppingList, householdId: UUID, userId: UUID, currencyCode: String = "GBP") {
        self.list = list
        self.currencyCode = currencyCode
        let vm = ShoppingListViewModel(
            repository: SupabaseShoppingRepository(),
            householdId: householdId,
            userId: userId,
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

                        Text("\(viewModel.transferableItems.count) item\(viewModel.transferableItems.count == 1 ? "" : "s") ready to transfer")
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
                        "\(viewModel.transferableItems.count) items ready to transfer to pantry"
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
                        showClearButton: true,
                        accessibilityLabel: "Search and add item",
                        onSubmit: {
                            Task {
                                await viewModel.addItem()
                                viewModel.clearSuggestions()
                            }
                        },
                        onClear: { viewModel.clearSuggestions() },
                        isFocused: $addFieldFocused
                    )

                    if let warning = viewModel.duplicateWarning {
                        HStack(spacing: AppSpacing.denseSpacing) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.gsWarning)
                                .font(BrandSymbolFont.symbol(12))
                            Text(warning)
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        .padding(.top, AppSpacing.compactGap)
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

                    ForEach(viewModel.catalogSuggestions) { item in
                        Button {
                            Task {
                                await viewModel.addCatalogItem(item)
                                viewModel.newItemName = ""
                                viewModel.clearSuggestions()
                            }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gsBrandPrimary)
                                    .font(BrandSymbolFont.symbol(20))

                                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                    Text(item.name)
                                        .font(BrandFont.regular(17))
                                        .foregroundStyle(.gsTextPrimary)
                                    Text("\(item.defaultCategory) · \(item.defaultUnit.displayName)")
                                        .font(BrandFont.regular(14))
                                        .foregroundStyle(.gsTextSecondary)
                                }

                                Spacer()
                            }
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }

                    if !viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !viewModel.isSearchingCatalog
                        && viewModel.catalogSuggestions.isEmpty
                        && viewModel.newItemName.count >= 2 {
                        Button {
                            Task {
                                await viewModel.addItem()
                                viewModel.clearSuggestions()
                            }
                        } label: {
                            HStack(spacing: AppSpacing.rowSpacing) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.gsBrandPrimary)
                                    .font(BrandSymbolFont.symbol(20))
                                Text("Add \"\(viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                                Spacer()
                            }
                        }
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

            // MARK: - To buy
            Section {
                ForEach(viewModel.pendingItems) { item in
                    ShoppingItemRow(item: item) {
                        Task { await viewModel.toggleComplete(item) }
                    }
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
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            itemToDelete = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                shoppingDetailSectionHeader(
                    title: "To buy",
                    count: viewModel.pendingItems.count,
                    emphasis: .standard
                )
            }

            // MARK: - Done
            if !viewModel.completedItems.isEmpty {
                Section {
                    ForEach(viewModel.completedItems) { item in
                        ShoppingItemRow(item: item) {
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
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteItem(item) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    shoppingDetailSectionHeader(
                        title: "Done",
                        count: viewModel.completedItems.count,
                        emphasis: .muted
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
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
            Task { await viewModel.refreshTransferredStatus() }
        }) {
            let auditVM = ShoppingAuditViewModel(
                transferableItems: viewModel.transferableItems,
                pantryItems: viewModel.pantryItems
            )
            if auditVM.hasMatches {
                ShoppingAuditView(
                    auditViewModel: auditVM,
                    transferableItems: viewModel.transferableItems,
                    householdId: list.householdId,
                    userId: list.createdBy,
                    listId: list.listId,
                    currencyCode: currencyCode
                )
            } else {
                TransferConfirmationView(
                    viewModel: TransferViewModel(
                        completedItems: viewModel.transferableItems,
                        pantryRepository: SupabasePantryRepository(),
                        transactionRepository: SupabaseTransactionRepository(),
                        shoppingRepository: SupabaseShoppingRepository(),
                        householdId: list.householdId,
                        userId: list.createdBy,
                        listId: list.listId
                    ),
                    currencyCode: currencyCode
                )
            }
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

    private func accessibilityLabelForSection(title: String, count: Int?) -> String {
        if let count {
            return "\(title), \(count) items"
        }
        return title
    }
}
