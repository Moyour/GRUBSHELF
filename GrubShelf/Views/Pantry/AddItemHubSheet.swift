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

    private let householdId: UUID
    private let userId: UUID

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

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
                        if cameraAvailable {
                            actionCard(
                                icon: "camera.fill",
                                title: "Snap to add"
                            ) {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            viewModel.prefillItem = item
            viewModel.prefillCatalogItem = nil
            viewModel.showAddForm = true
        } label: {
            VStack(alignment: .center, spacing: AppSpacing.smallSpacing) {
                Text(ItemIconMapper.emoji(for: item.name, category: item.category))
                    .font(BrandFont.regular(22))
                    .frame(maxWidth: .infinity)
                Text(item.name)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("+Add")
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(.gsBrandPrimary)
                    .frame(maxWidth: .infinity)
            }
            .padding(AppSpacing.compactGap)
            .frame(width: AppSpacing.quickAddCardSize, height: AppSpacing.quickAddCardSize, alignment: .center)
            .dashboardCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick add \(item.name)")
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
                HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                    Button {
                        viewModel.prefillCatalogItem = catalogItem
                        viewModel.prefillItem = nil
                        viewModel.showAddForm = true
                    } label: {
                        HStack(spacing: AppSpacing.rowSpacing) {
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
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open details for \(catalogItem.name)"))

                    Button {
                        Task {
                            await viewModel.quickAddFromCatalog(
                                catalogItem,
                                householdId: householdId,
                                userId: userId
                            )
                        }
                    } label: {
                        Group {
                            if viewModel.quickAddingCatalogItemId == catalogItem.id {
                                ProgressView()
                                    .tint(.gsBrandPrimary)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gsBrandPrimary)
                                    .font(BrandSymbolFont.symbol(20))
                            }
                        }
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.quickAddingCatalogItemId == catalogItem.id)
                    .accessibilityLabel(String(localized: "Add \(catalogItem.name) to pantry"))
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()
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

    // MARK: - Add/Edit Sheet

    @ViewBuilder
    private var addEditSheet: some View {
        if let catalogItem = viewModel.prefillCatalogItem {
            AddEditPantryItemView(
                viewModel: AddEditPantryItemViewModel(
                    repository: SupabasePantryRepository(),
                    householdId: householdId,
                    userId: userId,
                    catalogItem: catalogItem
                )
            )
        } else if let item = viewModel.prefillItem {
            AddEditPantryItemView(
                viewModel: AddEditPantryItemViewModel(
                    repository: SupabasePantryRepository(),
                    householdId: householdId,
                    userId: userId,
                    prefillFrom: item
                )
            )
        } else {
            let vm = AddEditPantryItemViewModel(
                repository: SupabasePantryRepository(),
                householdId: householdId,
                userId: userId
            )
            AddEditPantryItemView(viewModel: vm)
                .task {
                    if let image = recognizedImage {
                        await vm.recognizeFromPhoto(image: image)
                        recognizedImage = nil
                    }
                }
        }
    }
}
