import SwiftUI
import UIKit

struct AddItemHubSheet: View {
    @State private var viewModel: AddItemHubViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    /// Start at large so the add sheet does not read as "collapsed"; detent changes are user-controlled (drag).
    @State private var selectedDetent: PresentationDetent = .large
    @State private var showCameraPicker = false
    @State private var recognizedImage: UIImage?
    @State private var isBarExpanded = false
    @Environment(\.featureGateService) private var featureGateService

    private let householdId: UUID
    private let userId: UUID
    private let userRole: UserRole

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    init(
        pantryItems: [PantryItem],
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member,
        featureGateService: FeatureGateService? = nil
    ) {
        _viewModel = State(initialValue: AddItemHubViewModel(
            pantryItems: pantryItems,
            catalogRepository: SupabaseGroceryCatalogRepository(),
            featureGateService: featureGateService
        ))
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
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
                        if cameraAvailable {
                            actionCard(
                                icon: "camera.fill",
                                title: "Snap to add"
                            ) {
                                if let gate = featureGateService,
                                   !gate.requireFeature(.photoUploads) {
                                    return
                                }
                                showCameraPicker = true
                            }
                        }

                        actionCard(
                            icon: "pencil",
                            title: "Add manually"
                        ) {
                            viewModel.prefillItem = nil
                            viewModel.prefillCatalogItem = nil
                            recognizedImage = nil
                            viewModel.showAddForm = true
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.rowSpacing)
                .padding(.bottom, AppSpacing.sectionSpacing)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationTitle("Add to pantry")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if viewModel.addedCount > 0 {
                    addedItemsBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.addedCount > 0 ? "Done" : "Cancel") {
                        viewModel.showDismissSummary()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        // Prefer scrolling / buttons over the first touch snapping the sheet to a smaller detent.
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.searchText) {
            viewModel.triggerSearch()
        }
        .onChange(of: searchFocused) { _, focused in
            if focused {
                selectedDetent = .large
            }
        }
        .sheet(isPresented: $viewModel.showAddForm) {
            addEditSheet
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraImagePicker { image in
                recognizedImage = image
                viewModel.prefillItem = nil
                viewModel.prefillCatalogItem = nil
                viewModel.showAddForm = true
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Quick Add Section

    @ViewBuilder
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            Text("Quick add")
                .font(BrandFont.semiBold(18))
                .foregroundStyle(.gsTextPrimary)

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
        VStack(alignment: .center, spacing: AppSpacing.smallSpacing) {
            Image(systemName: "basket")
                .font(BrandSymbolFont.symbol(26, weight: .medium))
                .foregroundStyle(EmptyStateChrome.symbolTealGradient)
                .accessibilityHidden(true)
            Text("What you add shows up here for one-tap repeats.")
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
    }

    private func recentItemCard(_ item: PantryItem) -> some View {
        Button {
            Task {
                await viewModel.quickAddRecent(
                    item,
                    householdId: householdId,
                    userId: userId,
                    userRole: userRole
                )
            }
        } label: {
            VStack(alignment: .center, spacing: AppSpacing.smallSpacing) {
                if viewModel.quickAddingRecentItemId == item.itemId {
                    ProgressView()
                        .tint(.gsBrandPrimary)
                        .frame(maxWidth: .infinity)
                } else if viewModel.lastAddedRecentItemId == item.itemId {
                    Image(systemName: "checkmark.circle.fill")
                        .font(BrandSymbolFont.symbol(22))
                        .foregroundStyle(.gsSuccess)
                        .frame(maxWidth: .infinity)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(ItemIconMapper.emoji(for: item.name, category: item.category))
                        .font(BrandFont.regular(22))
                        .frame(maxWidth: .infinity)
                }
                Text(item.name)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                if viewModel.alreadyAdded(item.name) {
                    Text("Added")
                        .font(BrandFont.semiBold(14))
                        .foregroundStyle(.gsSuccess)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("+Add")
                        .font(BrandFont.semiBold(14))
                        .foregroundStyle(.gsBrandPrimary)
                        .frame(maxWidth: .infinity)
                }
                Text("Hold to edit")
                    .font(BrandFont.regular(11))
                    .foregroundStyle(.gsTextTertiary)
            }
            .animation(.spring(duration: 0.3), value: viewModel.lastAddedRecentItemId)
            .padding(AppSpacing.compactGap)
            .frame(width: AppSpacing.quickAddCardSize, height: AppSpacing.quickAddCardSize, alignment: .center)
            .dashboardCardSurface()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.quickAddingRecentItemId == item.itemId)
        .contextMenu {
            Button {
                viewModel.openEditForm(for: item)
            } label: {
                Label("Edit before adding", systemImage: "pencil")
            }
        }
        .accessibilityLabel("Quick add \(item.name)")
        .accessibilityHint("Adds one unit to your pantry. Long press to edit before adding.")
    }

    // MARK: - Search Section

    private var searchSection: some View {
        InlineSearchFieldRow(
            text: $viewModel.searchText,
            placeholder: "Search grocery catalog…",
            submitLabel: .search,
            autocorrectionDisabled: true,
            showClearButton: true,
            accessibilityLabel: "Search grocery catalog",
            onSubmit: nil,
            onClear: nil,
            isFocused: $searchFocused
        )
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.inlineSearchCardVerticalPadding)
        .dashboardCardSurface()
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
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsDanger)
            }

            ForEach(viewModel.catalogSearchVM.results) { catalogItem in
                Button {
                    Task {
                        await viewModel.quickAddFromCatalog(
                            catalogItem,
                            householdId: householdId,
                            userId: userId,
                            userRole: userRole
                        )
                    }
                } label: {
                    HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                        Text(ItemIconMapper.emoji(for: catalogItem.name, category: catalogItem.defaultCategory))
                            .font(BrandFont.regular(24))

                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            Text(catalogItem.name)
                                .font(BrandFont.regular(17))
                                .foregroundStyle(.gsTextPrimary)
                            Text("\(catalogItem.defaultCategory) · \(catalogItem.defaultUnit.displayName)")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Group {
                            if viewModel.quickAddingCatalogItemId == catalogItem.id {
                                ProgressView()
                                    .tint(.gsBrandPrimary)
                            } else if viewModel.lastAddedCatalogItemId == catalogItem.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.gsSuccess)
                                    .font(BrandSymbolFont.symbol(20))
                                    .transition(.scale.combined(with: .opacity))
                            } else if viewModel.alreadyAdded(catalogItem.name) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.gsSuccess)
                                    .font(BrandSymbolFont.symbol(20))
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gsBrandPrimary)
                                    .font(BrandSymbolFont.symbol(20))
                            }
                        }
                        .animation(.spring(duration: 0.3), value: viewModel.lastAddedCatalogItemId)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.quickAddingCatalogItemId == catalogItem.id)
                .contextMenu {
                    Button {
                        viewModel.openEditForm(for: catalogItem)
                    } label: {
                        Label("Edit before adding", systemImage: "pencil")
                    }
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()
                .accessibilityLabel(String(localized: "Add \(catalogItem.name) to pantry"))
                .accessibilityHint("Long press to edit before adding.")
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: icon)
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(.gsBrandPrimary)
                    .frame(width: 28)
                Text(title)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(BrandSymbolFont.symbol(14, weight: .regular))
                    .foregroundStyle(.gsTextSecondary)
            }
            .padding(AppSpacing.cardPadding)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .dashboardCardSurface()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Added Items Bar

    private var addedItemsBar: some View {
        VStack(spacing: 0) {
            // Collapsed header row (always visible)
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isBarExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(BrandSymbolFont.symbol(18))
                        .foregroundStyle(.gsSuccess)
                    Text("\(viewModel.addedCount) item\(viewModel.addedCount == 1 ? "" : "s") added")
                        .font(BrandFont.semiBold(15))
                        .foregroundStyle(.gsTextPrimary)
                    Image(systemName: isBarExpanded ? "chevron.down" : "chevron.up")
                        .font(BrandSymbolFont.symbol(12, weight: .semibold))
                        .foregroundStyle(.gsTextSecondary)
                    Spacer()
                    Button {
                        viewModel.showDismissSummary()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(.gsTextOnBrand)
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.smallSpacing)
                            .background(.gsBrandPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, AppSpacing.rowSpacing)

            // Expanded item list
            if isBarExpanded {
                Divider()
                    .padding(.horizontal, AppSpacing.screenPadding)

                ScrollView {
                    VStack(spacing: AppSpacing.smallSpacing) {
                        ForEach(viewModel.addedItems) { entry in
                            addedItemRow(entry)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.vertical, AppSpacing.rowSpacing)
                }
                .frame(maxHeight: 240)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.35), value: viewModel.addedCount)
        .onChange(of: viewModel.addedCount) { _, newCount in
            if newCount == 0 {
                withAnimation { isBarExpanded = false }
            }
        }
    }

    private func addedItemRow(_ entry: AddedPantryEntry) -> some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Text(ItemIconMapper.emoji(for: entry.name, category: entry.category))
                .font(BrandFont.regular(20))

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(entry.name)
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                Text(entry.unit.displayName)
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
            }

            Spacer()

            // Quantity stepper
            HStack(spacing: AppSpacing.smallSpacing) {
                Button {
                    let newQty = max(1, entry.quantity - 1)
                    viewModel.updateQuantity(itemId: entry.id, newQuantity: newQty)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(BrandSymbolFont.symbol(22))
                        .foregroundStyle(entry.quantity <= 1 ? .gsTextSecondary.opacity(0.3) : .gsBrandPrimary)
                }
                .buttonStyle(.plain)
                .disabled(entry.quantity <= 1)

                Text("\(Int(entry.quantity))")
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)
                    .frame(minWidth: 24, alignment: .center)

                Button {
                    viewModel.updateQuantity(itemId: entry.id, newQuantity: entry.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(BrandSymbolFont.symbol(22))
                        .foregroundStyle(.gsBrandPrimary)
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    viewModel.removeItem(itemId: entry.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(BrandSymbolFont.symbol(16))
                    .foregroundStyle(.gsDanger)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.smallSpacing)
        .background(Color.gsSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
    }

    // MARK: - Add/Edit Sheet

    @ViewBuilder
    private var addEditSheet: some View {
        if let catalogItem = viewModel.prefillCatalogItem {
            let vm = AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId,
                userRole: userRole,
                catalogItem: catalogItem
            )
            AddEditPantryItemView(viewModel: vm)
                .task {
                    vm.featureGateService = featureGateService
                    vm.onSaveSuccess = { [viewModel] item in viewModel.trackManualAdd(item) }
                }
        } else if let item = viewModel.prefillItem {
            let vm = AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId,
                userRole: userRole,
                prefillFrom: item
            )
            AddEditPantryItemView(viewModel: vm)
                .task {
                    vm.featureGateService = featureGateService
                    vm.onSaveSuccess = { [viewModel] item in viewModel.trackManualAdd(item) }
                }
        } else {
            let vm = AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId,
                userRole: userRole
            )
            AddEditPantryItemView(viewModel: vm)
                .task {
                    vm.featureGateService = featureGateService
                    vm.onSaveSuccess = { [viewModel] item in viewModel.trackManualAdd(item) }
                    if let image = recognizedImage {
                        await vm.recognizeFromPhoto(image: image)
                        recognizedImage = nil
                    }
                }
        }
    }
}
