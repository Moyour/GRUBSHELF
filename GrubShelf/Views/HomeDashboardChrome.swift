import SwiftUI

// MARK: - Home dashboard — Concept A "Calm Assistant"

// MARK: - Shared chrome (kept)

private struct HomeDashIconWell: View {
    let systemName: String
    let gradientColors: [Color]
    var size: CGFloat = 36
    var iconSize: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: gradientColors.last?.opacity(0.28) ?? .black.opacity(0.12), radius: 5, x: 0, y: 3)
            Image(systemName: systemName)
                .font(BrandSymbolFont.symbol(iconSize, weight: .semibold))
                .foregroundStyle(.gsTextOnBrand)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

private struct HomeSectionTitle: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            Image(systemName: systemImage)
                .font(BrandSymbolFont.symbol(14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [BrandPalette.Teal.s500, BrandPalette.Teal.s700],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(BrandFont.semiBold(15))
                .foregroundStyle(.gsTextPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - Header (kept)

struct HomeDashboardTealHeader: View {
    let greeting: String
    let householdName: String

    private var contextDateString: String {
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return fmt.string(from: Date.now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
            Text(greeting)
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextSecondary)
                .textCase(.none)
                .tracking(0.2)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.smallSpacing) {
                Text(householdName)
                    .font(BrandFont.bold(30))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(contextDateString)
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(BrandPalette.Teal.s700)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.rowSpacing)
        .padding(.bottom, AppSpacing.sectionSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). \(householdName). \(contextDateString)")
    }
}

// MARK: - Calm Hero Card

private struct CalmHeroCard: View {
    let expiringItems: [PantryItem]
    let lowStockCount: Int
    let totalItems: Int
    let wasteCount: Int
    let shoppingCompleted: Int
    let shoppingTotal: Int
    var onOpenExpiryCalendar: () -> Void
    var onOpenPantryTab: (PantryNavigationFocus?) -> Void
    var onNavigateToShopping: (() -> Void)?

    private enum HeroState {
        case expiring(names: [String], soonestDate: Date?)
        case lowStock(count: Int)
        case coldStart
        case allClear
    }

    private var heroState: HeroState {
        if !expiringItems.isEmpty {
            let names = Array(expiringItems.prefix(3).map(\.name))
            let soonest = expiringItems.compactMap(\.expiryDate).min()
            return .expiring(names: names, soonestDate: soonest)
        }
        if lowStockCount > 3 {
            return .lowStock(count: lowStockCount)
        }
        if totalItems == 0 {
            return .coldStart
        }
        return .allClear
    }

    private var heroEmoji: String {
        switch heroState {
        case .expiring: "🥦"
        case .lowStock: "📦"
        case .coldStart: "🛒"
        case .allClear: "🌿"
        }
    }

    private var heroTitle: String {
        switch heroState {
        case .expiring(_, _):
            let count = expiringItems.count
            if count == 1 {
                return String(localized: "1 item to use soon")
            }
            return String(format: String(localized: "%lld items to use soon"), Int64(count))
        case .lowStock(let count):
            return String(format: String(localized: "Running low on %lld staples"), Int64(count))
        case .coldStart:
            return String(localized: "Start with a shopping list")
        case .allClear:
            return String(localized: "You're all set")
        }
    }

    private var heroSubtitle: String {
        switch heroState {
        case .expiring(let names, let date):
            let nameList = HouseholdFeedFormatter.compactItemList(names, maxLength: 60)
            if let date {
                let fmt = RelativeDateTimeFormatter()
                fmt.unitsStyle = .short
                let relative = fmt.localizedString(for: date, relativeTo: .now)
                return "\(nameList) — \(relative)"
            }
            return nameList
        case .lowStock:
            return String(localized: "Time to restock a few essentials")
        case .coldStart:
            return String(localized: "Your pantry fills itself after you shop")
        case .allClear:
            return String(localized: "Pantry looks good this week")
        }
    }

    private var heroAction: () -> Void {
        switch heroState {
        case .expiring: onOpenExpiryCalendar
        case .lowStock: { onOpenPantryTab(.lowStock) }
        case .coldStart: { (onNavigateToShopping ?? { onOpenPantryTab(nil) })() }
        case .allClear: { onOpenPantryTab(nil) }
        }
    }

    private var actionLabel: String {
        switch heroState {
        case .expiring: String(localized: "View items →")
        case .lowStock: String(localized: "View low stock →")
        case .coldStart: String(localized: "Create a list →")
        case .allClear: String(localized: "Open pantry →")
        }
    }

    private let cardRadius = AppSpacing.heroRadius

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [BrandPalette.Teal.s800, BrandPalette.Teal.s600],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: heroAction) {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                Text(heroEmoji)
                    .font(.system(size: 36))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text(heroTitle)
                        .font(BrandFont.bold(24))
                        .foregroundStyle(.gsTextOnBrand)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(heroSubtitle)
                        .font(BrandFont.regular(15))
                        .foregroundStyle(Color.gsTextOnBrand.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(actionLabel)
                    .font(BrandFont.semiBold(14))
                    .foregroundStyle(.gsTextOnBrand)
                    .padding(.horizontal, AppSpacing.rowSpacing)
                    .padding(.vertical, AppSpacing.smallSpacing)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.gsTextOnBrand.opacity(0.18))
                    )
            }
            .padding(AppSpacing.cardPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.97))
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(Color.gsTextOnBrand.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, AppSpacing.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(heroTitle). \(heroSubtitle)")
        .accessibilityHint(actionLabel)
    }
}

// MARK: - Insight Story Strip

private struct InsightStoryStrip: View {
    let shoppingCompleted: Int
    let shoppingTotal: Int
    let hasBudget: Bool
    let lowStockCount: Int
    let wasteItemCount: Int
    let currentStreak: Int
    var onNavigateToShopping: () -> Void
    var onNavigateToInsights: () -> Void
    var onOpenPantryTab: (PantryNavigationFocus?) -> Void

    private struct Bubble: Identifiable {
        let id: String
        let emoji: String
        let label: String
        let ringColors: [Color]
        let action: () -> Void
    }

    private var bubbles: [Bubble] {
        var result: [Bubble] = []

        // 1. Shopping progress
        let pct = shoppingTotal > 0
            ? Int(Double(shoppingCompleted) / Double(shoppingTotal) * 100)
            : 0
        result.append(Bubble(
            id: "shop",
            emoji: "🛒",
            label: shoppingTotal > 0
                ? String(format: String(localized: "Shop %lld%%"), Int64(pct))
                : String(localized: "Shop"),
            ringColors: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
            action: onNavigateToShopping
        ))

        // 2. Budget (only if set)
        if hasBudget {
            result.append(Bubble(
                id: "budget",
                emoji: "💰",
                label: String(localized: "Budget"),
                ringColors: [BrandPalette.Exploration.softPlum, BrandPalette.Exploration.softPlum.opacity(0.6)],
                action: onNavigateToInsights
            ))
        }

        // 3. Low stock (only if > 0)
        if lowStockCount > 0 {
            result.append(Bubble(
                id: "low",
                emoji: "📦",
                label: String(format: String(localized: "%lld Low"), Int64(lowStockCount)),
                ringColors: [BrandPalette.Amber.s400, BrandPalette.Amber.s700],
                action: { onOpenPantryTab(.lowStock) }
            ))
        }

        // 4. Waste
        if wasteItemCount == 0 {
            result.append(Bubble(
                id: "waste",
                emoji: "🍃",
                label: String(localized: "No waste"),
                ringColors: [BrandPalette.Status.success, BrandPalette.Teal.s500],
                action: onNavigateToInsights
            ))
        } else {
            result.append(Bubble(
                id: "waste",
                emoji: "🗑️",
                label: String(format: String(localized: "%lld wasted"), Int64(wasteItemCount)),
                ringColors: [BrandPalette.Status.danger, BrandPalette.Status.danger.opacity(0.6)],
                action: onNavigateToInsights
            ))
        }

        // 5. Streak
        if currentStreak > 0 {
            result.append(Bubble(
                id: "streak",
                emoji: "🔥",
                label: String(format: String(localized: "%lld days"), Int64(currentStreak)),
                ringColors: [BrandPalette.Status.danger, BrandPalette.Amber.s400],
                action: onNavigateToInsights
            ))
        } else {
            result.append(Bubble(
                id: "streak",
                emoji: "🔥",
                label: String(localized: "0 days"),
                ringColors: [BrandPalette.Neutral.s400, BrandPalette.Neutral.s300],
                action: onNavigateToInsights
            ))
        }

        return result
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            packedStoryStrip
            scrollingStoryStrip
        }
    }

    private var packedStoryStrip: some View {
        HStack(spacing: AppSpacing.cardPadding) {
            ForEach(bubbles) { bubble in
                storyBubbleButton(bubble, flexibleColumn: true)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private var scrollingStoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.cardPadding) {
                ForEach(bubbles) { bubble in
                    storyBubbleButton(bubble, flexibleColumn: false)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    @ViewBuilder
    private func storyBubbleButton(_ bubble: Bubble, flexibleColumn: Bool) -> some View {
        Button(action: bubble.action) {
            if flexibleColumn {
                storyBubbleContent(bubble)
                    .frame(
                        minWidth: DashboardResponsiveLayout.storyStripPackedMinColumnWidth,
                        maxWidth: .infinity
                    )
            } else {
                storyBubbleContent(bubble)
                    .frame(width: 68)
            }
        }
        .buttonStyle(DashboardScaleButtonStyle())
        .accessibilityLabel(bubble.label)
    }

    private func storyBubbleContent(_ bubble: Bubble) -> some View {
        VStack(spacing: AppSpacing.denseSpacing) {
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: bubble.ringColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 56, height: 56)
                Text(bubble.emoji)
                    .font(.system(size: 24))
            }
            Text(bubble.label)
                .font(BrandFont.semiBold(12))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Contextual Action Card

private struct ContextualActionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let emoji: String
    let tintColors: [Color]
    let title: String
    let subtitle: String
    var action: () -> Void

    private var rowSurface: Color {
        colorScheme == .dark ? BrandPalette.Neutral.s700 : Color.gsSurface
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(colors: tintColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(emoji)
                            .font(.system(size: 20))
                    }

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(title)
                        .font(BrandFont.semiBold(14))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(subtitle)
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(BrandSymbolFont.symbol(12, weight: .semibold))
                    .foregroundStyle(.gsTextTertiary)
            }
            .padding(.horizontal, AppSpacing.rowSpacing)
            .padding(.vertical, AppSpacing.rowSpacing)
            .background(rowSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(
                        Color.gsBorder.opacity(colorScheme == .dark ? 0.72 : 0.5),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.035), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.98))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Glance Grid View

private struct GlanceGridView: View {
    @Environment(\.colorScheme) private var colorScheme

    let totalPantryItems: Int
    let categoriesCount: Int
    let expiringCount: Int
    let hasBudget: Bool
    let spendProgress: Double
    let budgetRemainingMinor: Int
    let currencyCode: String
    let wasteItemCount: Int
    var onOpenPantryTab: (PantryNavigationFocus?) -> Void
    var onNavigateToInsights: () -> Void
    var onOpenExpiryCalendar: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private var tileSurface: Color {
        colorScheme == .dark ? BrandPalette.Neutral.s700 : Color.gsSurface
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            // 1. Pantry
            glanceTile(
                emoji: "🥫",
                value: "\(totalPantryItems)",
                valueColor: .gsTextPrimary,
                label: String(localized: "Pantry items"),
                sub: String(
                    format: String(localized: "%lld categories"),
                    Int64(categoriesCount)
                ),
                action: { onOpenPantryTab(nil) }
            )

            // 2. Expiring
            glanceTile(
                emoji: "⏳",
                value: "\(expiringCount)",
                valueColor: expiringCount > 0 ? .gsWarning : .gsTextPrimary,
                label: String(localized: "Expiring soon"),
                sub: String(localized: "Within 5 days"),
                action: onOpenExpiryCalendar
            )

            // 3. Budget
            if hasBudget {
                budgetTile
            } else {
                glanceTile(
                    emoji: "💷",
                    value: "—",
                    valueColor: .gsTextTertiary,
                    label: String(localized: "Budget"),
                    sub: String(localized: "Not set up"),
                    action: onNavigateToInsights
                )
            }

            // 4. Waste
            glanceTile(
                emoji: "🍃",
                value: "\(wasteItemCount)",
                valueColor: wasteItemCount == 0 ? .gsSuccess : .gsTextPrimary,
                label: String(localized: "Waste events"),
                sub: wasteItemCount == 0
                    ? String(localized: "Great job!")
                    : String(localized: "This month"),
                action: onNavigateToInsights
            )
        }
    }

    private func glanceTile(
        emoji: String,
        value: String,
        valueColor: Color,
        label: String,
        sub: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack {
                    Text(emoji)
                        .font(.system(size: 20))
                    Spacer()
                    Text(value)
                        .font(BrandFont.mono(16))
                        .foregroundStyle(valueColor)
                        .contentTransition(.numericText())
                }

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(label)
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                    Text(sub)
                        .font(BrandFont.regular(12))
                        .foregroundStyle(.gsTextTertiary)
                        .lineLimit(1)
                }
            }
            .padding(AppSpacing.rowSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(
                        Color.gsBorder.opacity(colorScheme == .dark ? 0.72 : 0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(sub)")
    }

    private var budgetTile: some View {
        let pct = Int(spendProgress * 100)
        let remaining = budgetRemainingMinor.currencyFormatted(currencyCode: currencyCode)
        let sub = budgetRemainingMinor >= 0
            ? String(format: String(localized: "%@ left"), remaining)
            : String(localized: "Over budget")

        return Button(action: onNavigateToInsights) {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack {
                    Text("💷")
                        .font(.system(size: 20))
                    Spacer()
                    Text("\(pct)%")
                        .font(BrandFont.mono(16))
                        .foregroundStyle(.gsTextPrimary)
                        .contentTransition(.numericText())
                }

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(String(localized: "Budget used"))
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                    Text(sub)
                        .font(BrandFont.regular(12))
                        .foregroundStyle(.gsTextTertiary)
                        .lineLimit(1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gsBorder.opacity(0.3))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * min(spendProgress, 1.0)), height: 4)
                            .animation(.spring(response: 0.55, dampingFraction: 0.82), value: spendProgress)
                    }
                }
                .frame(height: 4)
            }
            .padding(AppSpacing.rowSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(
                        Color.gsBorder.opacity(colorScheme == .dark ? 0.72 : 0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Budget used: \(pct) percent. \(sub)"))
    }
}

// MARK: - Home shopping list (primary list, all items)

private struct HomeDashboardShoppingListSection: View {
    @Bindable var shoppingListsVM: ShoppingListsViewModel
    @Bindable var dashboardVM: DashboardViewModel
    var onNavigateToShopping: () -> Void

    var body: some View {
        if let preview = shoppingListsVM.homePrimaryListPreview {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HomeSectionTitle(
                    systemImage: "cart.fill",
                    title: String(localized: "Shopping list")
                )
                .padding(.horizontal, AppSpacing.screenPadding)

                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(preview.list.name)
                            .font(BrandFont.semiBold(16))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !preview.items.isEmpty {
                            Text("\(preview.items.filter(\.completed).count)/\(preview.items.count)")
                                .font(BrandFont.mono(14))
                                .foregroundStyle(.gsTextSecondary)
                                .accessibilityLabel(
                                    String(
                                        format: String(localized: "%lld of %lld items checked"),
                                        Int64(preview.items.filter(\.completed).count),
                                        Int64(preview.items.count)
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    if preview.items.isEmpty {
                        Text(String(localized: "No items yet — add some in Shop."))
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.screenPadding)
                    } else {
                        VStack(spacing: AppSpacing.compactGap) {
                            ForEach(preview.items) { item in
                                ShoppingItemRow(item: item) {
                                    Task {
                                        await shoppingListsVM.toggleActiveItem(item)
                                        await dashboardVM.loadData(forceRefresh: true)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }

                    Button {
                        onNavigateToShopping()
                    } label: {
                        HStack {
                            Text(String(localized: "Open Shop"))
                                .font(BrandFont.semiBold(15))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(BrandSymbolFont.symbol(12, weight: .semibold))
                        }
                        .foregroundStyle(.gsBrandPrimary)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.vertical, AppSpacing.smallSpacing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open Shop"))
                }
            }
        }
    }
}

// MARK: - Quick Actions Row

private struct QuickActionsRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let onAddItem: () -> Void
    let onLogPurchase: () -> Void

    private var surface: Color {
        colorScheme == .dark ? BrandPalette.Neutral.s700 : Color.gsSurface
    }

    var body: some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            quickActionButton(
                icon: "plus.circle.fill",
                label: String(localized: "Add item"),
                tint: BrandPalette.Teal.s600,
                action: onAddItem
            )
            quickActionButton(
                icon: "dollarsign.circle.fill",
                label: String(localized: "Log a spend"),
                tint: BrandPalette.Amber.s600,
                action: onLogPurchase
            )
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: AppSpacing.denseSpacing) {
                Image(systemName: icon)
                    .font(BrandSymbolFont.symbol(24, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(Color.gsBorder.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.96))
        .accessibilityLabel(label)
    }
}

// MARK: - Composed dashboard

struct HomeDashboardChrome: View {
    @Bindable var dashboardVM: DashboardViewModel
    @Bindable var financeVM: FinanceViewModel
    @Bindable var profileVM: ProfileViewModel
    @Bindable var shoppingListsVM: ShoppingListsViewModel
    @Environment(\.colorScheme) private var colorScheme

    let greetingTitle: String
    let lowStockSampleNames: [String]
    var onNavigateToInsights: () -> Void
    var onNavigateToShopping: () -> Void
    var onOpenPantryTab: (PantryNavigationFocus?) -> Void
    var onOpenExpiryCalendar: () -> Void
    var onAddItem: () -> Void
    var onLogPurchase: () -> Void

    private var householdDisplayName: String {
        let n = profileVM.householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? String(localized: "Your household") : n
    }

    // MARK: - Contextual action cards (max 2)

    private struct ActionDef: Identifiable {
        let id: String
        let emoji: String
        let tintColors: [Color]
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    private var actionCards: [ActionDef] {
        var cards: [ActionDef] = []

        // 1. Urgent expiry (within 2 days) — shows count of items expiring soon
        if let topExpiring = dashboardVM.expiringItems.first,
           let expiry = topExpiring.expiryDate {
            let daysUntil = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expiry)).day ?? 99
            if daysUntil <= 2 {
                let dayLabel: String
                if daysUntil <= 0 {
                    dayLabel = String(localized: "expires today")
                } else if daysUntil == 1 {
                    dayLabel = String(localized: "expires tomorrow")
                } else {
                    dayLabel = String(localized: "expires in 2 days")
                }
                let expiringCount = dashboardVM.expiringItems.count
                let itemsLabel = expiringCount == 1
                    ? String(localized: "1 item")
                    : String(format: String(localized: "%lld items"), Int64(expiringCount))
                cards.append(ActionDef(
                    id: "expiry",
                    emoji: "⏰",
                    tintColors: [BrandPalette.Amber.s400, BrandPalette.Amber.s700],
                    title: String(localized: "Expiring soon (\(itemsLabel))"),
                    subtitle: dayLabel,
                    action: onOpenExpiryCalendar
                ))
            }
        }

        // 2. Shopping list in progress — shows list name with item count
        if dashboardVM.shoppingTotal > 0 && dashboardVM.shoppingCompleted < dashboardVM.shoppingTotal {
            let remaining = dashboardVM.shoppingTotal - dashboardVM.shoppingCompleted
            let listName = shoppingListsVM.homePrimaryListPreview?.list.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedListName = (listName?.isEmpty == false ? listName! : String(localized: "Shopping list"))
            let total = dashboardVM.shoppingTotal
            let itemsLabel = total == 1
                ? String(localized: "1 item")
                : String(format: String(localized: "%lld items"), Int64(total))
            cards.append(ActionDef(
                id: "shopping",
                emoji: "🛍️",
                tintColors: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
                title: "\(resolvedListName) (\(itemsLabel))",
                subtitle: remaining == 1
                    ? String(localized: "1 item remaining")
                    : String(format: String(localized: "%lld items remaining"), Int64(remaining)),
                action: onNavigateToShopping
            ))
        }

        // 3. Budget setup nudge
        if !financeVM.hasBudget && cards.count < 2 {
            cards.append(ActionDef(
                id: "budget",
                emoji: "💰",
                tintColors: [BrandPalette.Amber.s400, BrandPalette.Amber.s600],
                title: String(localized: "Set up a budget"),
                subtitle: String(localized: "Track spending in 30 seconds"),
                action: onNavigateToInsights
            ))
        }

        return Array(cards.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Greeting header
            HomeDashboardTealHeader(
                greeting: greetingTitle,
                householdName: householdDisplayName
            )

            // 2. Smart hero card
            CalmHeroCard(
                expiringItems: dashboardVM.expiringItems,
                lowStockCount: dashboardVM.lowStockCount,
                totalItems: dashboardVM.totalPantryItems,
                wasteCount: dashboardVM.wasteItemCount,
                shoppingCompleted: dashboardVM.shoppingCompleted,
                shoppingTotal: dashboardVM.shoppingTotal,
                onOpenExpiryCalendar: onOpenExpiryCalendar,
                onOpenPantryTab: onOpenPantryTab,
                onNavigateToShopping: onNavigateToShopping
            )

            // 2.5 Quick actions
            QuickActionsRow(onAddItem: onAddItem, onLogPurchase: onLogPurchase)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.sectionSpacing)

            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                // 3. "At a glance" section
                VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                    HomeSectionTitle(
                        systemImage: "square.grid.2x2.fill",
                        title: String(localized: "At a glance")
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)

                    GlanceGridView(
                        totalPantryItems: dashboardVM.totalPantryItems,
                        categoriesCount: dashboardVM.categoriesCount,
                        expiringCount: dashboardVM.expiringCount,
                        hasBudget: financeVM.hasBudget,
                        spendProgress: financeVM.spendProgress,
                        budgetRemainingMinor: financeVM.budgetRemainingMinor,
                        currencyCode: financeVM.currencyCode,
                        wasteItemCount: dashboardVM.wasteItemCount,
                        onOpenPantryTab: onOpenPantryTab,
                        onNavigateToInsights: onNavigateToInsights,
                        onOpenExpiryCalendar: onOpenExpiryCalendar
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                // 4. Contextual action cards (0-2)
                if !actionCards.isEmpty {
                    VStack(spacing: AppSpacing.smallSpacing) {
                        ForEach(actionCards) { card in
                            ContextualActionCard(
                                emoji: card.emoji,
                                tintColors: card.tintColors,
                                title: card.title,
                                subtitle: card.subtitle,
                                action: card.action
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                // 5. Primary shopping list (all items, checkmarks reflect completion)
                HomeDashboardShoppingListSection(
                    shoppingListsVM: shoppingListsVM,
                    dashboardVM: dashboardVM,
                    onNavigateToShopping: onNavigateToShopping
                )

                // 6. Story bubbles strip
                InsightStoryStrip(
                    shoppingCompleted: dashboardVM.shoppingCompleted,
                    shoppingTotal: dashboardVM.shoppingTotal,
                    hasBudget: financeVM.hasBudget,
                    lowStockCount: dashboardVM.lowStockCount,
                    wasteItemCount: dashboardVM.wasteItemCount,
                    currentStreak: dashboardVM.currentStreak,
                    onNavigateToShopping: onNavigateToShopping,
                    onNavigateToInsights: onNavigateToInsights,
                    onOpenPantryTab: onOpenPantryTab
                )
            }
            .padding(.top, AppSpacing.sectionSpacing)
            .padding(.bottom, AppSpacing.rowSpacing)
        }
        .background(Color.gsBackground)
    }
}
