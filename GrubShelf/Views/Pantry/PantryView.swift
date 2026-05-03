import SwiftUI

struct PantryView: View {
    @State private var viewModel: PantryViewModel
    @State private var showEmptyState = false
    @State private var viewMode: PantryViewMode = .grid

    private enum PantryViewMode: String {
        case list, grid
    }

    init(viewModel: PantryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasLoaded {
                    PantrySkeletonView()
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    if viewMode == .grid {
                        pantryGridContent
                    } else {
                        pantryListContent
                    }
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                if viewModel.hasLoaded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewMode = viewMode == .grid ? .list : .grid
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        PrimaryPlusToolbarButton(
                            accessibilityLabel: "Add item",
                            accessibilityHint: "Double tap to add a new pantry item"
                        ) {
                            viewModel.showAddSheet = true
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search inventory…")
            .refreshable {
                await viewModel.loadItems(forceRefresh: true)
            }
            .background(.gsBackground)
            .task {
                await viewModel.loadItems()
            }
            .confirmationDialog(
                "Record outcome for \(viewModel.itemToRemove?.name ?? "this item")?",
                isPresented: $viewModel.showRemovalPrompt,
                titleVisibility: .visible
            ) {
                Button("Used") {
                    Task { await viewModel.confirmUsed() }
                }
                Button("Remove from list", role: .destructive) {
                    Task { await viewModel.confirmRemoveFromList() }
                }
                Button("Expired", role: .destructive) {
                    viewModel.beginExpiredRemoval()
                }
                Button("Waste", role: .destructive) {
                    viewModel.beginWasteRemoval()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRemovalFlow()
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
                    viewModel.cancelRemovalFlow()
                }
            }
            .sheet(item: $viewModel.itemToEdit) { item in
                AddEditPantryItemView(viewModel: AddEditPantryItemViewModel(
                    repository: viewModel.repository,
                    householdId: viewModel.householdId,
                    userId: viewModel.userId,
                    existingItem: item
                ))
            }
            .tint(.gsBrandPrimary)
        }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .center, spacing: AppSpacing.sectionSpacing) {
                Spacer(minLength: AppSpacing.scrollVerticalBreathingRoom)

                TabEmptyStateHero(
                    systemName: "refrigerator.fill",
                    symbolFontSize: EmptyStateMetrics.tabHeroSymbolSizeCompact,
                    symbolWeight: .bold,
                    imageAsset: "onboarding-pantry"
                )
                .opacity(showEmptyState ? 1 : 0)
                .scaleEffect(showEmptyState ? 1 : 0.92)

                EmptyStateCopyCard(
                    title: String(localized: "Your shelf is empty"),
                    subtitle: String(localized: "Add items to track expiry, low stock, and what's on hand—same quick flow as Home.")
                )
                .opacity(showEmptyState ? 1 : 0)
                .offset(y: showEmptyState ? 0 : 12)

                EmptyStateTealCTAButton(
                    title: String(localized: "Add your first item"),
                    systemImage: "plus.circle.fill"
                ) {
                    viewModel.showAddSheet = true
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

    // MARK: - Grid mode

    private var pantryGridContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PantryFilterChips(viewModel: viewModel)
                    .padding(.top, AppSpacing.compactGap)
                    .padding(.bottom, AppSpacing.rowSpacing)

                if !viewModel.searchText.isEmpty && viewModel.filteredItems.isEmpty {
                    EmptyStateInlineBlock(
                        systemName: "magnifyingglass",
                        symbolSize: 30,
                        title: String(localized: "Nothing matches that"),
                        subtitle: String(localized: "Try another word or clear the search.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sectionSpacing)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: AppSpacing.mediumSpacing),
                            GridItem(.flexible(), spacing: AppSpacing.mediumSpacing)
                        ],
                        spacing: AppSpacing.mediumSpacing
                    ) {
                        ForEach(viewModel.filteredItems) { item in
                            PantryGridCard(
                                item: item,
                                confidence: viewModel.confidence(for: item),
                                onTap: { viewModel.itemToEdit = item },
                                onMarkFinished: { viewModel.markFinished(item) },
                                onHalve: { Task { await viewModel.halveItem(item) } },
                                onDecrement: { Task { await viewModel.decrementItem(item) } }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                Spacer(minLength: AppSpacing.floatingAddButtonScrollClearance)
            }
        }
        .refreshable {
            await viewModel.loadItems(forceRefresh: true)
        }
    }

    // MARK: - List mode

    /// Single scroll surface: summary + location filter + rows (same layout fix as Shop lists).
    private var pantryListContent: some View {
        List {
            Section {
                PantrySummaryStrip(viewModel: viewModel)
                    .padding(.top, AppSpacing.compactGap)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                Picker("Location", selection: $viewModel.selectedLocationFilter) {
                    ForEach(PantryLocationFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(AppSpacing.listRowSectionControlInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !viewModel.searchText.isEmpty && viewModel.filteredItems.isEmpty {
                Section {
                    EmptyStateInlineBlock(
                        systemName: "magnifyingglass",
                        symbolSize: 30,
                        title: String(localized: "Nothing matches that"),
                        subtitle: String(localized: "Try another word or clear the search.")
                    )
                    .listRowInsets(AppSpacing.listRowCardInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else if viewModel.selectedLocationFilter == .all {
                ForEach(viewModel.groupedFilteredByCategory, id: \.category) { group in
                    Section {
                        ForEach(group.items) { item in
                            pantryRow(item)
                        }
                    } header: {
                        HStack {
                            Text(group.category)
                                .font(BrandFont.semiBold(18))
                            Spacer()
                            Text("\(group.items.count)")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                    }
                }
            } else {
                ForEach(viewModel.confidentFilteredItems) { item in
                    pantryRow(item)
                }

                if !viewModel.probablyGoneFilteredItems.isEmpty {
                    Section {
                        ForEach(viewModel.probablyGoneFilteredItems) { item in
                            pantryRow(item)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(BrandSymbolFont.symbol(15))
                            Text("Needs verification")
                                .font(BrandFont.semiBold(15))
                            Spacer()
                            Text("\(viewModel.probablyGoneFilteredItems.count)")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        .foregroundStyle(.gsTextSecondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(AppSpacing.rowSpacing)
    }

    private func pantryRow(_ item: PantryItem) -> some View {
        PantryItemRow(
            item: item,
            confidence: viewModel.confidence(for: item),
            onTapEdit: { viewModel.itemToEdit = item },
            onIncrement: { Task { await viewModel.incrementItem(item) } },
            onDecrement: { Task { await viewModel.decrementItem(item) } }
        )
            .listRowInsets(AppSpacing.listRowCardInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    viewModel.markFinished(item)
                } label: {
                    Label("Finished", systemImage: "checkmark.circle")
                }
                .tint(.gsBrandPrimary)
                Button {
                    Task { await viewModel.halveItem(item) }
                } label: {
                    Label("Half", systemImage: "divide")
                }
                .tint(.gsBrandPrimary)
                Button {
                    Task { await viewModel.decrementItem(item) }
                } label: {
                    Label("-1", systemImage: "minus.circle")
                }
                .tint(.gsBrandPrimary)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    viewModel.itemToEdit = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.gsBrandPrimary)
            }
    }

}

// MARK: - Grid Card

private struct PantryGridCard: View {
    let item: PantryItem
    let confidence: Double
    let onTap: () -> Void
    let onMarkFinished: () -> Void
    let onHalve: () -> Void
    let onDecrement: () -> Void

    private enum BadgeStyle {
        case ok, warning, danger
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                // Emoji + expiry badge row
                ZStack(alignment: .topTrailing) {
                    HStack {
                        Text(ItemIconMapper.emoji(for: item.name, category: item.category))
                            .font(.system(size: 32))
                        Spacer()
                    }

                    if let badge = expiryBadge {
                        Text(badge.text)
                            .font(BrandFont.semiBold(11))
                            .foregroundStyle(badgeForeground(badge.style))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeBackground(badge.style))
                            .clipShape(Capsule())
                    }
                }

                // Item name
                Text(item.name)
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Detail line: qty unit · location
                Text(detailText)
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)

                // Stock bar
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.gsBorder.opacity(0.3))
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(stockBarColor)
                                .frame(width: geo.size.width * stockFraction, height: 3)
                        }
                }
                .frame(height: 3)
            }
            .padding(AppSpacing.rowSpacing)
            .background(Color.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.97))
        .opacity(confidence < 0.7 ? max(0.55, confidence) : 1.0)
        .contextMenu {
            Button { onTap() } label: { Label("Edit", systemImage: "pencil") }
            Button { onMarkFinished() } label: { Label("Finished", systemImage: "checkmark.circle") }
            Button { onHalve() } label: { Label("Half", systemImage: "divide") }
            Button { onDecrement() } label: { Label("-1", systemImage: "minus.circle") }
        }
    }

    // MARK: - Computed helpers

    private var detailText: String {
        let qty = item.quantity.formatted()
        let unit = item.unit.abbreviation
        let loc = item.storageLocation.displayName
        return "\(qty)\(unit) · \(loc)"
    }

    private var expiryBadge: (text: String, style: BadgeStyle)? {
        if item.state == .lowStock { return ("Low", .danger) }
        if item.state == .expired { return ("Expired", .danger) }
        guard let expiry = item.expiryDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date.now)
        let expiryDay = Calendar.current.startOfDay(for: expiry)
        let days = Calendar.current.dateComponents([.day], from: today, to: expiryDay).day ?? 99
        if days <= 0 { return ("Expired", .danger) }
        if days <= 5 { return ("\(days)d", .warning) }
        return ("\(days)d", .ok)
    }

    private var stockFraction: Double {
        if item.lowStockThreshold > 0 {
            return min(item.quantity / item.lowStockThreshold, 1.0)
        }
        return item.quantity > 0 ? 1.0 : 0.0
    }

    private var stockBarColor: Color {
        switch item.state {
        case .expired, .lowStock:
            return .gsDanger
        case .expiringSoon:
            return .gsWarning
        default:
            return BrandPalette.Teal.s400
        }
    }

    private var cardBorderColor: Color {
        if item.state == .lowStock || item.state == .expired {
            return Color.gsDanger.opacity(0.45)
        }
        return Color.gsBorder.opacity(0.45)
    }

    private func badgeForeground(_ style: BadgeStyle) -> Color {
        switch style {
        case .ok: return BrandPalette.Teal.s700
        case .warning: return BrandPalette.Amber.s700
        case .danger: return Color.gsDanger
        }
    }

    private func badgeBackground(_ style: BadgeStyle) -> Color {
        switch style {
        case .ok: return BrandPalette.Teal.s50
        case .warning: return BrandPalette.Amber.s50
        case .danger: return Color.gsDanger.opacity(0.12)
        }
    }
}

// MARK: - Filter Chips

private struct PantryFilterChips: View {
    @Bindable var viewModel: PantryViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.denseSpacing) {
                // All items chip
                chipButton(
                    label: "All \(viewModel.pantryTotalActiveCount)",
                    isSelected: viewModel.selectedAttention == .none && viewModel.selectedLocationFilter == .all,
                    color: BrandPalette.Teal.s500
                ) {
                    viewModel.selectedAttention = .none
                    viewModel.selectedLocationFilter = .all
                }

                // Expiring chip
                if viewModel.pantryExpiringAttentionCount > 0 {
                    chipButton(
                        label: "\(viewModel.pantryExpiringAttentionCount) expiring",
                        isSelected: viewModel.selectedAttention == .expiring,
                        color: .gsWarning,
                        showDot: true
                    ) {
                        if viewModel.selectedAttention == .expiring {
                            viewModel.selectedAttention = .none
                        } else {
                            viewModel.selectedAttention = .expiring
                        }
                    }
                }

                // Low stock chip
                if viewModel.pantryLowStockAttentionCount > 0 {
                    chipButton(
                        label: "\(viewModel.pantryLowStockAttentionCount) low",
                        isSelected: viewModel.selectedAttention == .lowStock,
                        color: .gsDanger,
                        showDot: true
                    ) {
                        if viewModel.selectedAttention == .lowStock {
                            viewModel.selectedAttention = .none
                        } else {
                            viewModel.selectedAttention = .lowStock
                        }
                    }
                }

                Divider()
                    .frame(height: 20)

                // Location chips
                locationChip(.fridge)
                locationChip(.shelf)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    @ViewBuilder
    private func locationChip(_ location: PantryStorageLocation) -> some View {
        let count = viewModel.items.filter { !$0.archived && $0.quantity > 0 && $0.storageLocation == location }.count
        let locationFilter: PantryLocationFilter = location == .fridge ? .fridge : .shelf

        chipButton(
            label: "\(location.displayName) \(count)",
            isSelected: viewModel.selectedLocationFilter == locationFilter,
            color: BrandPalette.Teal.s500
        ) {
            if viewModel.selectedLocationFilter == locationFilter {
                viewModel.selectedLocationFilter = .all
            } else {
                viewModel.selectedLocationFilter = locationFilter
            }
        }
    }

    private func chipButton(
        label: String,
        isSelected: Bool,
        color: Color,
        showDot: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.compactGap) {
                if showDot {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(BrandFont.semiBold(13))
            }
            .padding(.horizontal, AppSpacing.mediumSpacing)
            .padding(.vertical, AppSpacing.filterChipOuterVerticalPadding)
            .background(isSelected ? color.opacity(0.15) : Color.gsSurface)
            .foregroundStyle(isSelected ? color : .gsTextSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.gsBorder.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
