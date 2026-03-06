import SwiftUI

struct PantryView: View {
    @State private var viewModel: PantryViewModel
    @Binding var showSettings: Bool

    init(viewModel: PantryViewModel, showSettings: Binding<Bool>) {
        _viewModel = State(initialValue: viewModel)
        _showSettings = showSettings
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if !viewModel.hasLoaded {
                    Color.clear
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        Picker("Filter", selection: $viewModel.selectedFilter) {
                            ForEach(PantryFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.vertical, AppSpacing.rowSpacing)

                        if !viewModel.searchText.isEmpty && viewModel.filteredItems.isEmpty {
                            noResultsView
                        } else if viewModel.selectedFilter == .categories {
                            categoriesView
                        } else {
                            itemListView
                        }
                    }
                }

                FloatingAddButton {
                    viewModel.showAddSheet = true
                }
                .padding(AppSpacing.screenPadding)
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search items…")
            .background(Color.appBackground)
            .task {
                await viewModel.loadItems()
                viewModel.startObserving()
            }
            .onDisappear {
                viewModel.stopObserving()
            }
            .confirmationDialog(
                "What happened to \(viewModel.itemToRemove?.name ?? "this item")?",
                isPresented: $viewModel.showRemovalPrompt,
                titleVisibility: .visible
            ) {
                Button("Used it") {
                    Task { await viewModel.confirmUsed() }
                }
                Button("Wasted / Expired", role: .destructive) {
                    viewModel.confirmWasted()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.itemToRemove = nil
                }
            }
            .alert("Roughly how much did this cost?", isPresented: $viewModel.showWasteCostPrompt) {
                TextField("Cost", text: $viewModel.wasteCostText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    Task { await viewModel.saveWasteEvent() }
                }
                Button("Skip") {
                    Task { await viewModel.saveWasteEvent(skipCost: true) }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.itemToRemove = nil
                    viewModel.wasteCostText = ""
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddItemHubSheet(
                    pantryItems: viewModel.items,
                    householdId: viewModel.householdId,
                    userId: viewModel.userId
                )
            }
            .sheet(item: $viewModel.itemToEdit) { item in
                AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                    repository: viewModel.repository,
                    householdId: viewModel.householdId,
                    userId: viewModel.userId,
                    existingItem: item
                ))
            }
        }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                Spacer(minLength: 40)

                Image("onboarding-pantry")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 200)
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.rowSpacing) {
                    Text("Your Pantry is Empty")
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.primaryText)

                    Text("Add items to track expiry dates, quantities, and reduce food waste.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Label("Add Your First Item", systemImage: "plus.circle.fill")
                        .font(AppFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(Color.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var noResultsView: some View {
        VStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppFont.emptyStateIconSizeSecondary))
                .foregroundStyle(Color.secondaryText.opacity(0.5))
            Text("No results for \"\(viewModel.searchText)\"")
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(.center)
            Text("Try a different search term")
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var itemListView: some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                pantryRow(item)
            }
        }
        .listStyle(.plain)
    }

    private func pantryRow(_ item: PantryItem) -> some View {
        PantryItemRow(
            item: item,
            onIncrement: { Task { await viewModel.incrementItem(item) } },
            onDecrement: { Task { await viewModel.decrementItem(item) } }
        )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.itemToEdit = item
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    viewModel.markFinished(item)
                } label: {
                    Label("Finished", systemImage: "checkmark.circle")
                }
                .tint(Color.errorRed)
                Button {
                    Task { await viewModel.halveItem(item) }
                } label: {
                    Label("Half", systemImage: "divide")
                }
                .tint(Color.warningAmber)
                Button {
                    Task { await viewModel.decrementItem(item) }
                } label: {
                    Label("-1", systemImage: "minus.circle")
                }
                .tint(Color.accentBlue)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    viewModel.itemToEdit = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
    }

    private var categoriesView: some View {
        List {
            ForEach(viewModel.groupedByCategory, id: \.category) { group in
                Section {
                    ForEach(group.items) { item in
                        pantryRow(item)
                    }
                } header: {
                    HStack {
                        Text(group.category)
                            .font(AppFont.sectionTitle)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
