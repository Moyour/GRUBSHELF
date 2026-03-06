import SwiftUI

struct ShoppingListDetailView: View {
    @State private var viewModel: ShoppingListViewModel
    @FocusState private var addFieldFocused: Bool

    private let list: ShoppingList

    init(list: ShoppingList, householdId: UUID, userId: UUID) {
        self.list = list
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
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.successGreen)
                        Text("\(viewModel.transferableItems.count) item\(viewModel.transferableItems.count == 1 ? "" : "s") ready to transfer")
                            .font(AppFont.body)
                        Spacer()
                        Button("Transfer") {
                            viewModel.showTransferSheet = true
                        }
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryGreen)
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .padding(AppSpacing.cardPadding)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .cardShadow()
                }
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.rowSpacing / 2,
                    leading: AppSpacing.screenPadding,
                    bottom: AppSpacing.rowSpacing / 2,
                    trailing: AppSpacing.screenPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if viewModel.listTransferred {
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.successGreen)
                        Text("Transferred to pantry")
                            .font(AppFont.body)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .padding(AppSpacing.cardPadding)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .cardShadow()
                }
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.rowSpacing / 2,
                    leading: AppSpacing.screenPadding,
                    bottom: AppSpacing.rowSpacing / 2,
                    trailing: AppSpacing.screenPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            // MARK: - Summary Stats (#3)
            if !viewModel.items.isEmpty {
                Section {
                    HStack(spacing: 0) {
                        ActionPill(
                            icon: "bag",
                            value: "\(viewModel.pendingItems.count)",
                            label: "Pending",
                            color: .warningAmber
                        )
                        ActionPill(
                            icon: "checkmark.circle",
                            value: "\(viewModel.completedItems.count)",
                            label: "Completed",
                            color: .successGreen
                        )
                        ActionPill(
                            icon: "arrow.right.circle",
                            value: "\(viewModel.transferableItems.count)",
                            label: "Transfer",
                            color: .primaryGreen
                        )
                    }
                }
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.rowSpacing / 2,
                    leading: AppSpacing.screenPadding,
                    bottom: AppSpacing.rowSpacing / 2,
                    trailing: AppSpacing.screenPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            // MARK: - Add Item Section (#6 — card style)
            Section {
                VStack(spacing: 0) {
                    HStack(spacing: AppSpacing.rowSpacing) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundStyle(Color.secondaryText)
                            .accessibilityHidden(true)

                        TextField("Search & add item…", text: $viewModel.newItemName)
                            .font(AppFont.body)
                            .focused($addFieldFocused)
                            .onSubmit {
                                Task {
                                    await viewModel.addItem()
                                    viewModel.clearSuggestions()
                                }
                            }
                            .submitLabel(.done)

                        if !viewModel.newItemName.isEmpty {
                            Button {
                                viewModel.newItemName = ""
                                viewModel.clearSuggestions()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear")
                        }
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Search and add item")

                    if let warning = viewModel.duplicateWarning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.warningAmber)
                                .font(.caption)
                            Text(warning)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.warningAmber)
                        }
                        .padding(.top, 4)
                    }

                    if viewModel.isSearchingCatalog {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching…")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.top, 8)
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
                                    .foregroundStyle(Color.primaryGreen)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(AppFont.body)
                                        .foregroundStyle(Color.primaryText)
                                    Text("\(item.defaultCategory) · \(item.defaultUnit.displayName)")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.secondaryText)
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
                                    .foregroundStyle(Color.primaryGreen)
                                    .font(.title3)
                                Text("Add \"\(viewModel.newItemName.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                            }
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .cardShadow()
            }
            .listRowInsets(EdgeInsets(
                top: AppSpacing.rowSpacing / 2,
                leading: AppSpacing.screenPadding,
                bottom: AppSpacing.rowSpacing / 2,
                trailing: AppSpacing.screenPadding
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // MARK: - Items Section (#5 — card layout)
            Section {
                ForEach(viewModel.pendingItems) { item in
                    ShoppingItemRow(item: item) {
                        Task { await viewModel.toggleComplete(item) }
                    }
                    .listRowInsets(EdgeInsets(
                        top: AppSpacing.rowSpacing / 2,
                        leading: AppSpacing.screenPadding,
                        bottom: AppSpacing.rowSpacing / 2,
                        trailing: AppSpacing.screenPadding
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                ForEach(viewModel.completedItems) { item in
                    ShoppingItemRow(item: item) {
                        Task { await viewModel.toggleComplete(item) }
                    }
                    .opacity(0.5)
                    .listRowInsets(EdgeInsets(
                        top: AppSpacing.rowSpacing / 2,
                        leading: AppSpacing.screenPadding,
                        bottom: AppSpacing.rowSpacing / 2,
                        trailing: AppSpacing.screenPadding
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Items (\(viewModel.pendingItems.count) left)")
                    Spacer()
                    if !viewModel.completedItems.isEmpty {
                        Text("\(viewModel.completedItems.count) done")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.successGreen)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(list.name)
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    addFieldFocused = false
                }
                .font(AppFont.button)
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
            TransferConfirmationView(viewModel: TransferViewModel(
                completedItems: viewModel.transferableItems,
                pantryRepository: SupabasePantryRepository(),
                transactionRepository: SupabaseTransactionRepository(),
                shoppingRepository: SupabaseShoppingRepository(),
                householdId: list.householdId,
                userId: list.createdBy,
                listId: list.listId
            ))
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
    }
}
