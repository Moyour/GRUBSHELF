import SwiftUI

struct AddItemHubSheet: View {
    @State private var viewModel: AddItemHubViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    @State private var selectedDetent: PresentationDetent = .medium

    private let householdId: UUID
    private let userId: UUID

    init(pantryItems: [PantryItem], householdId: UUID, userId: UUID) {
        _viewModel = State(initialValue: AddItemHubViewModel(
            pantryItems: pantryItems,
            catalogRepository: SupabaseGroceryCatalogRepository()
        ))
        self.householdId = householdId
        self.userId = userId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                    // MARK: - Quick Add Recent Items
                    quickAddSection

                    // MARK: - Search Bar
                    searchSection

                    // MARK: - Catalog Results
                    if !viewModel.searchText.isEmpty {
                        catalogResultsSection
                    }

                    // MARK: - Action Cards
                    VStack(spacing: AppSpacing.rowSpacing) {
                        actionCard(
                            icon: "barcode.viewfinder",
                            title: "Scan Barcode"
                        ) {
                            viewModel.showBarcodeScanner = true
                        }

                        actionCard(
                            icon: "pencil",
                            title: "Add Manually"
                        ) {
                            viewModel.prefillItem = nil
                            viewModel.prefillCatalogItem = nil
                            viewModel.showAddForm = true
                        }
                    }

                    if viewModel.isLookingUpBarcode {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Text("Looking up product…")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.rowSpacing)
                .padding(.bottom, AppSpacing.sectionSpacing)
            }
            .navigationTitle("Add to Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.searchText) {
            viewModel.triggerSearch()
        }
        .onChange(of: searchFocused) { _, focused in
            if focused {
                selectedDetent = .large
            }
        }
        .sheet(isPresented: $viewModel.showBarcodeScanner) {
            NavigationStack {
                BarcodeScannerView { code in
                    Task { await viewModel.handleBarcode(code) }
                }
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.showBarcodeScanner = false }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddForm) {
            addEditSheet
        }
    }

    // MARK: - Quick Add Section

    @ViewBuilder
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            Text("Quick Add")
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.primaryText)

            if viewModel.recentItems.isEmpty {
                emptyRecentState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.rowSpacing) {
                        ForEach(viewModel.recentItems) { item in
                            recentItemCard(item)
                        }
                    }
                }
            }
        }
    }

    private var emptyRecentState: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Image(systemName: "basket")
                .font(.title3)
                .foregroundStyle(Color.secondaryText)
            Text("Items you add will appear here for quick re-adding")
                .font(AppFont.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }

    private func recentItemCard(_ item: PantryItem) -> some View {
        Button {
            viewModel.prefillItem = item
            viewModel.prefillCatalogItem = nil
            viewModel.showAddForm = true
        } label: {
            VStack(spacing: 6) {
                Text(categoryEmoji(for: item.category))
                    .font(.title2)
                Text(item.name)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("+Add")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.primaryGreen)
            }
            .frame(width: 80, height: 90)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondaryText)
            TextField("Search grocery catalog…", text: $viewModel.searchText)
                .font(AppFont.body)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }

    // MARK: - Catalog Results

    @ViewBuilder
    private var catalogResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            if viewModel.catalogSearchVM.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, AppSpacing.rowSpacing)
            }

            if let error = viewModel.catalogSearchVM.errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.errorRed)
            }

            ForEach(viewModel.catalogSearchVM.results) { catalogItem in
                Button {
                    viewModel.prefillCatalogItem = catalogItem
                    viewModel.prefillItem = nil
                    viewModel.showAddForm = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(catalogItem.name)
                                .font(AppFont.body)
                                .foregroundStyle(Color.primaryText)
                            Text("\(catalogItem.defaultCategory) · \(catalogItem.defaultUnit.displayName)")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.primaryGreen)
                            .font(.title3)
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .cardShadow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.primaryGreen)
                    .frame(width: 28)
                Text(title)
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(AppSpacing.cardPadding)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add/Edit Sheet

    @ViewBuilder
    private var addEditSheet: some View {
        if let catalogItem = viewModel.prefillCatalogItem {
            AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId,
                catalogItem: catalogItem
            ))
        } else if let item = viewModel.prefillItem {
            AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId,
                prefillFrom: item
            ))
        } else if let name = viewModel.barcodeName {
            let vm = AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId
            )
            AddEditPantryItemView(viewModel: vm)
                .onAppear {
                    vm.name = name
                    if let cat = viewModel.barcodeCategory {
                        if AddEditPantryItemViewModel.predefinedCategories.contains(cat) {
                            vm.category = cat
                        } else {
                            vm.category = "Custom"
                            vm.customCategory = cat
                        }
                    }
                    viewModel.barcodeName = nil
                    viewModel.barcodeCategory = nil
                }
        } else {
            AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId
            ))
        }
    }

    // MARK: - Helpers

    private func categoryEmoji(for category: String) -> String {
        switch category.lowercased() {
        case "fruits": return "🍎"
        case "vegetables": return "🥦"
        case "dairy": return "🧀"
        case "meat": return "🥩"
        case "seafood": return "🐟"
        case "grains": return "🌾"
        case "snacks": return "🍪"
        case "beverages": return "🥤"
        case "frozen": return "🧊"
        case "condiments": return "🧂"
        case "african staples": return "🫓"
        case "african spices": return "🌶️"
        default: return "🛒"
        }
    }
}
