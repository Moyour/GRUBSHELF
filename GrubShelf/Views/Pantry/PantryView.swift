import SwiftUI

struct PantryView: View {
    @State private var viewModel: PantryViewModel
    @State private var showEmptyState = false
    @State private var showPendingApprovals = false
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
                } else if let errorMessage = viewModel.errorMessage {
                    pantryErrorStateView(errorMessage: errorMessage)
                } else if viewModel.approvedItems.isEmpty
                    && viewModel.pendingApprovalItems.isEmpty
                    && viewModel.myRejectedItems.isEmpty {
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
                        .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
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
                    userRole: viewModel.userRole,
                    existingItem: item
                ))
            }
            .tint(.gsBrandPrimary)
            .alert("Reject item?", isPresented: $viewModel.showRejectReasonPrompt) {
                TextField("Reason (optional)", text: $viewModel.rejectReasonText)
                Button("Reject", role: .destructive) {
                    Task { await viewModel.confirmRejectItem() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRejectItem()
                }
            } message: {
                if let name = viewModel.itemToReject?.name {
                    Text("\"\(name)\" won’t be added until approved.")
                }
            }
            .sheet(isPresented: $showPendingApprovals) {
                NavigationStack {
                    PendingApprovalsView(householdId: viewModel.householdId)
                }
                .presentationDetents([.large])
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()

            // Large hero icon with background circle
            ZStack {
                Circle()
                    .fill(.gsBrandPrimary.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.gsBrandPrimary)
                    .symbolRenderingMode(.hierarchical)
            }

            // Title with better typography
            VStack(spacing: 8) {
                Text("Your Pantry is Empty")
                    .font(BrandFont.semiBold(26))
                    .foregroundStyle(.gsTextPrimary)

                Text("Start tracking what you have on hand")
                    .font(BrandFont.regular(16))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Feature hints - more compact
            VStack(spacing: 12) {
                EmptyStateFeatureRow(
                    icon: "calendar.badge.clock",
                    text: "Track expiry dates"
                )
                EmptyStateFeatureRow(
                    icon: "chart.bar.fill",
                    text: "Monitor stock levels"
                )
                EmptyStateFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    text: "Sync with shopping lists"
                )
            }
            .padding(.horizontal, AppSpacing.screenPadding * 2)

            // CTA button - compact
            Button {
                viewModel.showAddSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add Your First Item")
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
    }

    // Helper view for feature rows
    private struct EmptyStateFeatureRow: View {
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

    // MARK: - Grid mode

    private var pantryGridContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasPendingApprovalBanner {
                    pantryPendingBanner
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.rowSpacing)
                }

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
                                canModify: viewModel.canModifyItem(item),
                                onTap: {
                                    if viewModel.canModifyItem(item) {
                                        viewModel.itemToEdit = item
                                    }
                                },
                                onMarkFinished: { Task { await viewModel.markFinished(item) } },
                                onMoreRemovalOptions: { viewModel.showRemovalOptions(for: item) },
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
        VStack(spacing: 0) {
            if hasPendingApprovalBanner {
                pantryPendingBanner
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, AppSpacing.rowSpacing)
            }

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
    }

    private var hasPendingApprovalBanner: Bool {
        (viewModel.isAdmin && !viewModel.pendingApprovalItems.isEmpty)
            || (!viewModel.isAdmin && !viewModel.myPendingItems.isEmpty)
            || (!viewModel.isAdmin && !viewModel.myRejectedItems.isEmpty)
    }

    @ViewBuilder
    private var pantryPendingBanner: some View {
        if viewModel.isAdmin && !viewModel.pendingApprovalItems.isEmpty {
            PendingApprovalPantrySection(
                role: .admin,
                items: viewModel.pendingApprovalItems,
                onReviewAll: viewModel.pendingApprovalItems.count > 1 ? { showPendingApprovals = true } : nil,
                onApprove: { item in Task { await viewModel.approveItem(item) } },
                onReject: { item in viewModel.beginRejectItem(item) }
            )
        } else if !viewModel.isAdmin && !viewModel.myPendingItems.isEmpty {
            PendingApprovalPantrySection(role: .memberWaiting, items: viewModel.myPendingItems)
        } else if !viewModel.isAdmin && !viewModel.myRejectedItems.isEmpty {
            PendingApprovalPantrySection(role: .memberRejected, items: viewModel.myRejectedItems)
        }
    }

    private func pantryRow(_ item: PantryItem) -> some View {
        PantryItemRow(
            item: item,
            confidence: viewModel.confidence(for: item),
            onTapEdit: viewModel.canModifyItem(item) ? { viewModel.itemToEdit = item } : nil,
            onIncrement: viewModel.canModifyItem(item) ? { Task { await viewModel.incrementItem(item) } } : nil,
            onDecrement: viewModel.canModifyItem(item) ? { Task { await viewModel.decrementItem(item) } } : nil
        )
            .listRowInsets(AppSpacing.listRowCardInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.canModifyItem(item) && item.isApproved {
                    Button {
                        Task { await viewModel.markFinished(item) }
                    } label: {
                        Label("Used", systemImage: "checkmark.circle")
                    }
                    .tint(.gsSuccess)
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
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if viewModel.canModifyItem(item) && item.isApproved {
                    Button {
                        viewModel.beginWasteRemoval(for: item)
                    } label: {
                        Label("Waste", systemImage: "trash")
                    }
                    .tint(.gsWarning)
                    Button {
                        viewModel.itemToEdit = item
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.gsBrandPrimary)
                }
            }
            .contextMenu {
                if viewModel.canModifyItem(item) && item.isApproved {
                    Button {
                        Task { await viewModel.markFinished(item) }
                    } label: {
                        Label("Used", systemImage: "checkmark.circle")
                    }
                    Button {
                        viewModel.showRemovalOptions(for: item)
                    } label: {
                        Label("More options…", systemImage: "ellipsis.circle")
                    }
                }
            }
    }

    // MARK: - Error State

    private func pantryErrorStateView(errorMessage: String) -> some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            VStack(spacing: AppSpacing.rowSpacing) {
                ZStack {
                    Circle()
                        .fill(.gsWarning.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.gsWarning)
                }

                VStack(spacing: AppSpacing.compactGap) {
                    Text("Couldn't Load Pantry")
                        .font(BrandFont.semiBold(20))
                        .foregroundStyle(.gsTextPrimary)

                    Text(errorMessage)
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await viewModel.loadItems(forceRefresh: true) }
                } label: {
                    Text("Try Again")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextOnBrand)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.plain)
                .background(.gsBrandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
                .padding(.horizontal, AppSpacing.screenPadding * 2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.screenPadding)
    }

}

// MARK: - Grid Card

private struct PantryGridCard: View {
    let item: PantryItem
    let confidence: Double
    var canModify: Bool = true
    let onTap: () -> Void
    let onMarkFinished: () -> Void
    var onMoreRemovalOptions: (() -> Void)?
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

                    if item.approvalStatus != .approved {
                        ApprovalStatusBadge(status: item.approvalStatus)
                    } else if let badge = expiryBadge {
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
            if canModify {
                Button { onTap() } label: { Label("Edit", systemImage: "pencil") }
                Button { onMarkFinished() } label: { Label("Used", systemImage: "checkmark.circle") }
                if let onMoreRemovalOptions {
                    Button { onMoreRemovalOptions() } label: {
                        Label("More options…", systemImage: "ellipsis.circle")
                    }
                }
                Button { onHalve() } label: { Label("Half", systemImage: "divide") }
                Button { onDecrement() } label: { Label("-1", systemImage: "minus.circle") }
            }
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
                            viewModel.setAttention(.none)
                        } else {
                            viewModel.setAttention(.expiring)
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
