import SwiftUI

@MainActor
enum DashboardContextualSubtitle {
    static func subtitle(for vm: DashboardViewModel) -> String {
        if vm.healthScore >= 80 { return "Stock levels and dates look stable." }
        if vm.expiringCount > 0 { return "\(vm.expiringCount) item\(vm.expiringCount == 1 ? "" : "s") with upcoming expiry" }
        if vm.lowStockCount > 0 { return "\(vm.lowStockCount) item\(vm.lowStockCount == 1 ? "" : "s") below minimum quantity" }
        if vm.totalPantryItems == 0 { return "No inventory recorded — add items to track stock and dates." }
        return "Review inventory and shopping activity below."
    }
}

// MARK: - Rich Overview Layout

/// Overview cards and hero (used on Home; optional pantry shortcut when shown alone).
struct DashboardOverviewContent: View {
    let viewModel: DashboardViewModel
    let financeVM: FinanceViewModel
    let animateScore: Bool
    @Binding var showPantryReview: Bool
    var showsPantryShortcutCard: Bool
    /// When `false`, hides the horizontal insights carousel (e.g. overview sheet mirrors Home’s “Today’s actions”).
    var showInsightsCarousel: Bool = true
    var onNavigateToInsights: (() -> Void)?
    var onNavigateToPantry: (() -> Void)?
    var onNavigateToShopping: (() -> Void)?
    var onQuickAction: ((DashboardQuickAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            SolidTealDashboardHero(
                headline: viewModel.overviewHeadline,
                contextualSubtitle: DashboardContextualSubtitle.subtitle(for: viewModel),
                healthScore: viewModel.healthScore,
                animate: animateScore
            )

            if showInsightsCarousel {
                InsightsCarousel(
                    viewModel: viewModel,
                    financeVM: financeVM,
                    onNavigateToInsights: onNavigateToInsights,
                    onNavigateToPantry: onNavigateToPantry,
                    onNavigateToShopping: onNavigateToShopping
                )
            }

            RichQuickActionsRow(onAction: onQuickAction)
                .padding(.horizontal, AppSpacing.screenPadding)

            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                ContextualAlertsSection(
                    expiringItems: viewModel.expiringItems,
                    lowStockCount: viewModel.lowStockCount,
                    onNavigateToPantry: onNavigateToPantry
                )

                if showsPantryShortcutCard {
                    Button { onNavigateToPantry?() } label: {
                        RichPantryCard(
                            totalItems: viewModel.totalPantryItems,
                            categoriesCount: viewModel.categoriesCount,
                            lowStockCount: viewModel.lowStockCount
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: AppSpacing.mediumSpacing) {
                    Button { onNavigateToShopping?() } label: {
                        RichShoppingCard(viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 0, maxWidth: .infinity)

                    RichBudgetCompactCard(
                        financeVM: financeVM,
                        onNavigateToInsights: onNavigateToInsights
                    )
                    .frame(minWidth: 0, maxWidth: .infinity)
                }

                if viewModel.staleCount > 0 {
                    RichNeedsReviewCard(count: viewModel.staleCount) {
                        showPantryReview = true
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
        .padding(.bottom, AppSpacing.rowSpacing)
    }
}

struct DashboardRichLayout: View {
    let viewModel: DashboardViewModel
    let financeVM: FinanceViewModel
    let animateScore: Bool
    @Binding var showPantryReview: Bool
    var onNavigateToInsights: (() -> Void)?
    var onNavigateToPantry: (() -> Void)?
    var onNavigateToShopping: (() -> Void)?
    var onQuickAction: ((DashboardQuickAction) -> Void)?

    var body: some View {
        ScrollView {
            DashboardOverviewContent(
                viewModel: viewModel,
                financeVM: financeVM,
                animateScore: animateScore,
                showPantryReview: $showPantryReview,
                showsPantryShortcutCard: true,
                onNavigateToInsights: onNavigateToInsights,
                onNavigateToPantry: onNavigateToPantry,
                onNavigateToShopping: onNavigateToShopping,
                onQuickAction: onQuickAction
            )
        }
        // Lets nested horizontal carousels (e.g. Insights) lock to horizontal drags instead of fighting the vertical scroll.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}

// MARK: - Solid teal hero (color-preview mockup)

struct SolidTealDashboardHero: View {
    let headline: String
    let contextualSubtitle: String
    let healthScore: Int
    let animate: Bool

    private let ringDiameter: CGFloat = 80
    private let ringLineWidth: CGFloat = 8

    private var healthFraction: CGFloat {
        animate ? CGFloat(healthScore) / 100.0 : 0
    }

    private var accessibilitySummary: String {
        [headline, "Inventory health \(healthScore) percent", contextualSubtitle].joined(separator: ". ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                Text(headline)
                    .font(BrandFont.bold(24))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                Text(contextualSubtitle)
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            HStack(alignment: .center, spacing: AppSpacing.mediumSpacing) {
                ZStack {
                    Circle()
                        .stroke(Color.gsTextOnBrand.opacity(0.15), lineWidth: ringLineWidth)
                        .frame(width: ringDiameter, height: ringDiameter)
                    Circle()
                        .trim(from: 0, to: healthFraction)
                        .stroke(Color.gsTextOnBrand, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                    Text("\(animate ? healthScore : 0)")
                        .font(BrandFont.bold(22))
                        .foregroundStyle(.gsTextOnBrand)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(width: ringDiameter, height: ringDiameter)
                .animation(.easeOut(duration: 1.0), value: animate)

                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text("Inventory")
                        .font(BrandFont.semiBold(16))
                        .foregroundStyle(Color.gsTextOnBrand.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                    Text(contextualSubtitle)
                        .font(BrandFont.regular(15))
                        .foregroundStyle(Color.gsTextOnBrand.opacity(0.5))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                    .fill(BrandPalette.Teal.s800)
            )
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.smallSpacing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
}

// MARK: - Triple Ring Hero

struct TripleRingHero: View {
    let greeting: String
    let subtitle: String
    let healthScore: Int
    let spendProgress: Double
    let hasBudget: Bool
    let wasteItemCount: Int
    let totalPantryItems: Int
    let animate: Bool

    private let ringWidth: CGFloat = 12

    private var healthFraction: CGFloat {
        animate ? CGFloat(healthScore) / 100.0 : 0
    }

    private var budgetFraction: CGFloat {
        guard hasBudget else { return 0 }
        return animate ? CGFloat(1.0 - spendProgress) : 0
    }

    private var wasteFraction: CGFloat {
        guard animate else { return 0 }
        if wasteItemCount == 0 { return 1.0 }
        return max(0, 1.0 - CGFloat(wasteItemCount) / 10.0)
    }

    private var wasteColor: Color {
        wasteItemCount == 0 ? .gsSuccess : .gsDanger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            // Greeting
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                Text(greeting)
                    .font(BrandFont.bold(30))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            // Rings
            HStack {
                Spacer()
                ZStack {
                    // Outer ring — Pantry Health (160pt)
                    ringTrack(diameter: 160, color: .gsBrandPrimary)
                    ringArc(diameter: 160, fraction: healthFraction, color: .gsBrandPrimary)

                    // Middle ring — Budget (120pt)
                    if hasBudget {
                        ringTrack(diameter: 120, color: .gsBrandPrimary)
                        ringArc(diameter: 120, fraction: budgetFraction, color: .gsBrandPrimary)
                    }

                    // Inner ring — Waste (80pt)
                    ringTrack(diameter: 80, color: wasteColor)
                    ringArc(diameter: 80, fraction: wasteFraction, color: wasteColor)

                    // Center score
                    Text("\(animate ? healthScore : 0)")
                        .font(BrandFont.bold(30))
                        .foregroundStyle(.gsTextPrimary)
                        .contentTransition(.numericText())
                }
                .frame(width: 180, height: 180)
                .animation(.easeOut(duration: 1.0), value: animate)
                Spacer()
            }

            // Legend
            HStack(spacing: AppSpacing.rowSpacing) {
                legendDot(color: .gsBrandPrimary, label: "Pantry")
                if hasBudget {
                    legendDot(color: .gsBrandPrimary, label: "Budget")
                }
                legendDot(color: wasteColor, label: "Waste")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                .fill(.gsBrandPrimary.opacity(0.06))
        )
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.smallSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dashboard health: \(healthScore) percent. \(wasteItemCount) wasted items.")
    }

    private func ringTrack(diameter: CGFloat, color: Color) -> some View {
        Circle()
            .stroke(color.opacity(0.1), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
    }

    private func ringArc(diameter: CGFloat, fraction: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(-90))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: AppSpacing.compactGap) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
        }
    }
}

// MARK: - Streak XP Bar

struct StreakXPBar: View {
    let currentStreak: Int

    private var level: Int { currentStreak / 7 + 1 }
    private var weekProgress: Int { currentStreak % 7 }

    var body: some View {
        HStack(spacing: AppSpacing.mediumSpacing) {
            // Flame + count
            HStack(spacing: AppSpacing.compactGap) {
                Image(systemName: "flame.fill")
                    .font(BrandSymbolFont.symbol(16))
                    .foregroundStyle(currentStreak > 0 ? .gsBrandPrimary : .gsTextSecondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: currentStreak > 0)
                Text("\(currentStreak)")
                    .font(BrandFont.mono(16))
                    .foregroundStyle(currentStreak > 0 ? .gsBrandPrimary : .gsTextSecondary)
            }

            // 7-day dots
            HStack(spacing: AppSpacing.compactGap) {
                ForEach(0..<7, id: \.self) { day in
                    Circle()
                        .fill(day < weekProgress ? .gsBrandPrimary : .gsBrandPrimary.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Level badge
            Text("Level \(level)")
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsBrandPrimary)
                .padding(.horizontal, AppSpacing.mediumSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(
                    Capsule()
                        .fill(.gsBrandPrimary.opacity(0.08))
                )
        }
        .padding(AppSpacing.rowSpacing)
        .dashboardCardSurface()
        .accessibilityLabel("\(currentStreak) day streak, Level \(level)")
    }
}

// MARK: - Insights Carousel

struct InsightCardData: Identifiable {
    let id = UUID()
    let icon: String
    let stat: String
    let description: String
    let color: Color
    var isHero: Bool = false
    var onTap: (() -> Void)? = nil
}

struct InsightsCarousel: View {
    let viewModel: DashboardViewModel
    let financeVM: FinanceViewModel
    var onNavigateToInsights: (() -> Void)?
    var onNavigateToPantry: (() -> Void)?
    var onNavigateToShopping: (() -> Void)?

    /// Must match `HStack` spacing and `containerRelativeFrame` spacing so snap alignment and gaps stay consistent.
    private static let interCardSpacing = AppSpacing.mediumSpacing

    private var cards: [InsightCardData] {
        var result: [InsightCardData] = []

        // Most purchased item → Insights
        if let item = viewModel.mostPurchasedItem {
            result.append(InsightCardData(
                icon: "bag.fill",
                stat: "\(viewModel.mostPurchasedCount)x",
                description: "Most frequent purchase: \(item)",
                color: .gsBrandPrimary,
                onTap: onNavigateToInsights
            ))
        }

        // Waste status → Insights (hero candidate when zero waste)
        if viewModel.wasteItemCount == 0 {
            result.append(InsightCardData(
                icon: "leaf.fill",
                stat: "No waste",
                description: "No waste events logged this month",
                color: .gsSuccess,
                isHero: true,
                onTap: onNavigateToInsights
            ))
        } else {
            let costStr = viewModel.wasteTotalMinor > 0
                ? " (\(viewModel.wasteTotalMinor.currencyFormatted(currencyCode: financeVM.currencyCode)))"
                : ""
            result.append(InsightCardData(
                icon: "trash.fill",
                stat: "\(viewModel.wasteItemCount)",
                description: "Waste events this month\(costStr)",
                color: .gsDanger,
                onTap: onNavigateToInsights
            ))
        }

        // Shopping completion → Shopping tab
        if viewModel.shoppingTotal > 0 {
            let pct = Int(viewModel.completionPercentage)
            result.append(InsightCardData(
                icon: "cart.fill",
                stat: "\(pct)%",
                description: pct == 100
                    ? "Shopping list completed"
                    : "Shopping progress: \(viewModel.shoppingCompleted) of \(viewModel.shoppingTotal)",
                color: .gsBrandPrimary,
                onTap: onNavigateToShopping
            ))
        }

        // Budget usage → Insights
        if financeVM.hasBudget {
            let pct = Int(financeVM.spendProgress * 100)
            result.append(InsightCardData(
                icon: "sterlingsign.circle.fill",
                stat: "\(pct)%",
                description: financeVM.budgetRemainingMinor >= 0
                    ? "Remaining: \(financeVM.budgetRemainingMinor.currencyFormatted(currencyCode: financeVM.currencyCode))"
                    : "Over budget",
                color: financeVM.budgetRemainingMinor >= 0 ? .gsBrandPrimary : .gsDanger,
                onTap: onNavigateToInsights
            ))
        }

        // Expiring items → Pantry tab
        if viewModel.expiringCount > 0 {
            result.append(InsightCardData(
                icon: "clock.badge.exclamationmark",
                stat: "\(viewModel.expiringCount)",
                description: "Upcoming expiry: \(viewModel.expiringCount) item\(viewModel.expiringCount == 1 ? "" : "s")",
                color: .gsWarning,
                onTap: onNavigateToPantry
            ))
        }

        // If no hero was set, promote the first card
        if !result.isEmpty && !result.contains(where: { $0.isHero }) {
            result[0] = InsightCardData(
                icon: result[0].icon,
                stat: result[0].stat,
                description: result[0].description,
                color: result[0].color,
                isHero: true,
                onTap: result[0].onTap
            )
        }

        return result
    }

    var body: some View {
        if !cards.isEmpty {
            ViewThatFits(in: .horizontal) {
                packedInsightsRow
                scrollingInsightsRow
            }
            .padding(.bottom, AppSpacing.smallSpacing)
        }
    }

    /// Equal-width row when the device is wide enough for `minWidth` on every card (no horizontal scroll).
    private var packedInsightsRow: some View {
        HStack(spacing: Self.interCardSpacing) {
            ForEach(cards) { card in
                InsightCard(data: card)
                    .frame(
                        minWidth: DashboardResponsiveLayout.insightsCarouselPackedMinCardWidth,
                        maxWidth: .infinity
                    )
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    /// Peeking card carousel when packed layout does not fit.
    private var scrollingInsightsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.interCardSpacing) {
                ForEach(cards) { card in
                    InsightCard(data: card)
                        .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: Self.interCardSpacing)
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, AppSpacing.screenPadding, for: .scrollContent)
    }
}

struct InsightCard: View {
    let data: InsightCardData

    /// Matches Home “At a glance” summary styling so horizontal carousels feel like one system.
    private static let cardCornerStyle = RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
    /// Two lines of `BrandFont.regular(14)` at default size (~15pt line height each) so short copy does not shrink card height.
    private static let descriptionBlockMinHeight: CGFloat = 34

    var body: some View {
        let content = VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
            HStack(alignment: .top, spacing: AppSpacing.smallSpacing) {
                Image(systemName: data.icon)
                    .font(BrandSymbolFont.symbol(18, weight: .semibold))
                    .foregroundStyle(data.isHero ? Color.gsTextOnBrand.opacity(0.8) : data.color)
                Spacer(minLength: 0)
                Text(data.stat)
                    .font(BrandFont.bold(22))
                    .foregroundStyle(data.isHero ? .gsTextOnBrand : .gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
            }
            Text(data.description)
                .font(BrandFont.regular(14))
                .foregroundStyle(data.isHero ? Color.gsTextOnBrand.opacity(0.75) : .gsTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: Self.descriptionBlockMinHeight, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(Self.cardCornerStyle)
        .overlay(
            data.isHero ? nil : Self.cardCornerStyle
                .strokeBorder(Color.gsBorder.opacity(0.55), lineWidth: 1)
        )
        .cardShadowIfHero(data.isHero)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.stat): \(data.description)")

        if let onTap = data.onTap {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if data.isHero {
            BrandPalette.Teal.s800
        } else {
            Color.gsSurface
        }
    }
}

// MARK: - Contextual Alerts

struct ContextualAlertsSection: View {
    let expiringItems: [PantryItem]
    let lowStockCount: Int
    var onNavigateToPantry: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            if !expiringItems.isEmpty {
                NavigationLink {
                    ExpiryCalendarView(items: expiringItems)
                } label: {
                    RichExpiryCard(items: expiringItems)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if lowStockCount > 3 {
                Button { onNavigateToPantry?() } label: {
                    LowStockAlertCard(
                        count: lowStockCount,
                        compact: !expiringItems.isEmpty
                    )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: expiringItems.count)
        .animation(.easeInOut(duration: 0.4), value: lowStockCount)
    }
}

struct LowStockAlertCard: View {
    let count: Int
    /// When `true` (e.g. expiring alert is already shown), use a lighter row so one warning dominates.
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                prominentBody
            }
        }
        .accessibilityLabel("\(count) items running low on stock")
    }

    private var prominentBody: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(.gsWarning.opacity(0.15))
                    .frame(width: AppSpacing.iconSizeLarge, height: AppSpacing.iconSizeLarge)
                Image(systemName: "arrow.down.circle.fill")
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(.gsWarning)
            }
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                Text("Running low")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                Text("\(count) below your minimum")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: AppSpacing.smallSpacing)
            Image(systemName: "chevron.right.circle.fill")
                .font(BrandSymbolFont.symbol(20))
                .foregroundStyle(.gsWarning.opacity(0.6))
        }
        .padding(AppSpacing.cardPadding)
        .background(.gsWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.gsWarning.opacity(0.22), lineWidth: 1)
        )
    }

    private var compactBody: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.gsWarning.opacity(0.9))
                .frame(width: 3)
            HStack(spacing: AppSpacing.smallSpacing) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(BrandSymbolFont.symbol(17))
                    .foregroundStyle(.gsWarning)
                Text("Also \(count) low on stock")
                    .font(BrandFont.regular(16))
                    .foregroundStyle(.gsTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(BrandSymbolFont.symbol(12, weight: .semibold))
                    .foregroundStyle(.gsTextSecondary)
            }
            .padding(.horizontal, AppSpacing.rowSpacing)
            .padding(.vertical, AppSpacing.smallSpacing)
        }
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.gsBorder.opacity(0.55), lineWidth: 1)
        )
    }
}

// MARK: - Rich Layout Components (Legacy)

struct RichHeroSection: View {
    let greeting: String
    let subtitle: String
    let streak: Int
    let healthScore: Int
    let healthLabel: String
    let animate: Bool

    private var scoreColor: Color {
        switch healthScore {
        case 80...100: return .gsBrandPrimary
        case 60..<80: return .gsBrandPrimary
        case 40..<60: return .gsTextSecondary
        default: return .gsTextSecondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text(greeting)
                        .font(BrandFont.bold(30))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: AppSpacing.smallSpacing)
                HStack(spacing: AppSpacing.smallSpacing) {
                    StreakBadge(count: streak)
                    Text("\(animate ? healthScore : 0)")
                        .font(BrandFont.bold(26))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                        .padding(.horizontal, AppSpacing.rowSpacing)
                        .padding(.vertical, AppSpacing.denseSpacing)
                        .background(scoreColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .layoutPriority(1)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                    .fill(scoreColor.opacity(0.1))
            )
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.smallSpacing)
        }
    }
}

struct RichQuickActionsRow: View {
    enum Style {
        /// Full-width bar with dividers and shadow (Overview sheet).
        case fullWidthBar
        /// Intrinsic-width cluster, leading-aligned, flat border — less dominant on Home.
        case compactLeading
    }

    var onAction: ((DashboardQuickAction) -> Void)?
    var style: Style = .fullWidthBar

    var body: some View {
        switch style {
        case .fullWidthBar:
            fullWidthBarBody
        case .compactLeading:
            compactLeadingBody
        }
    }

    private var fullWidthBarBody: some View {
        HStack(spacing: 0) {
            RichQuickActionButton(
                icon: "plus.circle.fill",
                label: "Add item",
                circleColor: BrandPalette.Teal.s800,
                expandsToFill: true
            ) { onAction?(.addItem) }
            quickActionDivider
            RichQuickActionButton(
                icon: "cart.fill",
                label: "Shopping",
                circleColor: BrandPalette.Exploration.warmCoral,
                expandsToFill: true
            ) { onAction?(.shopping) }
            quickActionDivider
            RichQuickActionButton(
                icon: "dollarsign.circle.fill",
                label: "Log purchase",
                circleColor: BrandPalette.Exploration.softPlum,
                expandsToFill: true
            ) { onAction?(.logPurchase) }
        }
        .padding(.vertical, AppSpacing.smallSpacing)
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.gsBorder.opacity(0.55), lineWidth: 1)
        )
        .cardShadow()
    }

    private var compactLeadingBody: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: AppSpacing.rowSpacing) {
                RichQuickActionButton(
                    icon: "plus.circle.fill",
                    label: "Add",
                    circleColor: BrandPalette.Teal.s800,
                    expandsToFill: false,
                    compactCircle: true
                ) { onAction?(.addItem) }
                RichQuickActionButton(
                    icon: "cart.fill",
                    label: "Shop",
                    circleColor: BrandPalette.Exploration.warmCoral,
                    expandsToFill: false,
                    compactCircle: true
                ) { onAction?(.shopping) }
                RichQuickActionButton(
                    icon: "dollarsign.circle.fill",
                    label: "Log",
                    circleColor: BrandPalette.Exploration.softPlum,
                    expandsToFill: false,
                    compactCircle: true
                ) { onAction?(.logPurchase) }
            }
            .padding(.horizontal, AppSpacing.smallSpacing)
            .padding(.vertical, AppSpacing.smallSpacing)
            .background(Color.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.bannerCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.bannerCornerRadius, style: .continuous)
                    .stroke(Color.gsBorder.opacity(0.45), lineWidth: 1)
            )
            Spacer(minLength: 0)
        }
    }

    private var quickActionDivider: some View {
        Rectangle()
            .fill(Color.gsBorder.opacity(0.35))
            .frame(width: 1)
            .padding(.vertical, AppSpacing.smallSpacing)
    }
}

struct RichQuickActionButton: View {
    let icon: String
    let label: String
    let circleColor: Color
    var expandsToFill: Bool = true
    var compactCircle: Bool = false
    let action: () -> Void

    private var circleSize: CGFloat { compactCircle ? AppSpacing.iconSizeSmall : AppSpacing.iconSizeMedium }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.compactGap) {
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: circleSize, height: circleSize)
                    Image(systemName: icon)
                        .font(compactCircle ? BrandSymbolFont.symbol(15) : BrandSymbolFont.symbol(17))
                        .foregroundStyle(.gsTextOnBrand)
                }
                Text(label)
                    .font(BrandFont.semiBold(compactCircle ? 10 : 11))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: compactCircle ? 56 : nil)
            .frame(maxWidth: expandsToFill ? .infinity : nil)
            .padding(.vertical, AppSpacing.smallSpacing)
            .padding(.horizontal, expandsToFill ? AppSpacing.compactGap : AppSpacing.denseSpacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelForCompact)
    }

    private var accessibilityLabelForCompact: String {
        switch label {
        case "Add": return "Add item"
        case "Shop": return "Shopping"
        case "Log": return "Log purchase"
        default: return label
        }
    }
}

struct AccentCard: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: AppSpacing.mediumSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: AppSpacing.iconSizeLarge, height: AppSpacing.iconSizeLarge)
                Image(systemName: icon)
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(accentColor)
            }
            Text(value)
                .font(BrandFont.bold(22))
                .foregroundStyle(.gsTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.cardPadding)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.gsBorder.opacity(0.4), lineWidth: 1)
        )
    }
}

struct RichExpiryCard: View {
    let items: [PantryItem]

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(.gsWarning.opacity(0.15))
                    .frame(width: AppSpacing.iconSizeLarge, height: AppSpacing.iconSizeLarge)
                Image(systemName: "clock.badge.exclamationmark")
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(.gsWarning)
            }
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                Text("Use these soon")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                Text("\(items.count) nearing expiry")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: AppSpacing.smallSpacing)
            Image(systemName: "chevron.right.circle.fill")
                .font(BrandSymbolFont.symbol(20))
                .foregroundStyle(.gsWarning.opacity(0.6))
        }
        .padding(AppSpacing.cardPadding)
        .background(.gsWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.gsWarning.opacity(0.28), lineWidth: 1)
        )
    }
}

struct RichPantryCard: View {
    let totalItems: Int
    let categoriesCount: Int
    let lowStockCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(spacing: AppSpacing.mediumSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                        .fill(.gsBrandPrimary.opacity(0.15))
                        .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                    Image(systemName: "refrigerator.fill")
                        .font(BrandSymbolFont.symbol(20))
                        .foregroundStyle(.gsBrandPrimary)
                }
                Text("Pantry")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.smallSpacing) {
                    Text("\(totalItems)")
                        .font(BrandFont.bold(22))
                        .foregroundStyle(.gsTextPrimary)
                    Text("items")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }
                HStack(spacing: AppSpacing.mediumSpacing) {
                    Label("\(categoriesCount) categories", systemImage: "folder.fill")
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if lowStockCount > 0 {
                        Label("\(lowStockCount) low", systemImage: "arrow.down.circle.fill")
                            .font(BrandFont.semiBold(13))
                            .foregroundStyle(.gsWarning)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(.gsBorder, lineWidth: 1)
        )
    }
}

struct RichShoppingCard: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
            HStack(spacing: AppSpacing.mediumSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                        .fill(.gsBrandPrimary.opacity(0.15))
                        .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                    Image(systemName: "cart.fill")
                        .font(BrandSymbolFont.symbol(20))
                        .foregroundStyle(.gsBrandPrimary)
                }
                Text("Shopping")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
            }
            if viewModel.shoppingTotal > 0 {
                Text("\(viewModel.shoppingCompleted)/\(viewModel.shoppingTotal)")
                    .font(BrandFont.bold(22))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                ProgressView(value: viewModel.completionPercentage, total: 100)
                    .tint(.gsBrandPrimary)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            } else {
                Text("No items")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(.gsBorder, lineWidth: 1)
        )
    }
}

struct RichBudgetCompactCard: View {
    let financeVM: FinanceViewModel
    var onNavigateToInsights: (() -> Void)?

    private var accentColor: Color {
        switch financeVM.budgetColor {
        case .green: return BrandPalette.Exploration.softPlum
        case .amber: return .gsWarning
        case .red: return .gsDanger
        }
    }

    var body: some View {
        Group {
            if financeVM.hasBudget {
                VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
                    HStack(spacing: AppSpacing.mediumSpacing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                            Image(systemName: "sterlingsign.circle.fill")
                                .font(BrandSymbolFont.symbol(20))
                                .foregroundStyle(accentColor)
                        }
                        Text("Budget")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                    }
                    Text("\(Int(financeVM.spendProgress * 100))%")
                        .font(BrandFont.bold(22))
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(1)
                    ProgressView(value: financeVM.spendProgress, total: 1)
                        .tint(accentColor)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.cardPadding)
                .background(Color.gsSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(.gsBorder, lineWidth: 1)
                )
            } else if let onNavigate = onNavigateToInsights {
                Button(action: onNavigate) {
                    VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
                        HStack(spacing: AppSpacing.mediumSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(BrandPalette.Exploration.softPlum.opacity(0.15))
                                    .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                                Image(systemName: "sterlingsign.circle.fill")
                                    .font(BrandSymbolFont.symbol(20))
                                    .foregroundStyle(BrandPalette.Exploration.softPlum)
                            }
                            Text("Budget")
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextPrimary)
                        }
                        Text("Set up")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                    .background(Color.gsSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                            .stroke(.gsBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set up budget")
            }
        }
    }
}

struct RichNeedsReviewCard: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
                HStack(spacing: AppSpacing.mediumSpacing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                            .fill(.gsWarning.opacity(0.15))
                            .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                        Image(systemName: "eye.fill")
                            .font(BrandSymbolFont.symbol(20))
                            .foregroundStyle(.gsWarning)
                    }
                    Text("Review")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                }
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(BrandFont.bold(22))
                    .foregroundStyle(.gsTextPrimary)
                Text("marked for review")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(.gsWarning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.gsWarning.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) items need review")
    }
}

// MARK: - Action Pill (shared component)

struct ActionPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.smallSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(color.opacity(0.12))
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                Image(systemName: icon)
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(BrandFont.bold(22))
                .foregroundStyle(.gsTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.cardPadding)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .pillShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Budget Progress Card

struct BudgetProgressCard: View {
    let financeVM: FinanceViewModel
    var onNavigateToInsights: (() -> Void)?

    private var budgetColor: Color {
        switch financeVM.budgetColor {
        case .green: return .gsBrandPrimary
        case .amber: return .gsWarning
        case .red: return .gsDanger
        }
    }

    var body: some View {
        if financeVM.hasBudget {
            DashboardCard(accentColor: budgetColor) {
                VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
                    HStack {
                        Image(systemName: "sterlingsign.circle.fill")
                            .font(BrandSymbolFont.symbol(20))
                            .foregroundStyle(budgetColor)
                        Text("Budget")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                        Spacer(minLength: AppSpacing.smallSpacing)
                        Text(financeVM.currentPeriodLabel)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack {
                        Text("Spent")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                        Text(financeVM.totalSpentMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    ProgressView(value: financeVM.spendProgress, total: 1)
                        .tint(budgetColor)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        .accessibilityLabel("Budget progress")
                        .accessibilityValue("\(Int(financeVM.spendProgress * 100)) percent spent")

                    HStack(spacing: AppSpacing.smallSpacing) {
                        Group {
                            if financeVM.budgetRemainingMinor >= 0 {
                                Text("\(financeVM.budgetRemainingMinor.currencyFormatted(currencyCode: financeVM.currencyCode)) remaining")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                            } else {
                                Text("\(abs(financeVM.budgetRemainingMinor).currencyFormatted(currencyCode: financeVM.currencyCode)) over")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                            }
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        Spacer(minLength: AppSpacing.smallSpacing)
                        Text("of \(financeVM.budgetAmountMinor.currencyFormatted(currencyCode: financeVM.currencyCode))")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        } else if let onNavigate = onNavigateToInsights {
            DashboardCard(accentColor: .gsBrandPrimary) {
                Button(action: onNavigate) {
                    HStack(spacing: AppSpacing.rowSpacing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(.gsBrandPrimary.opacity(0.12))
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            Image(systemName: "sterlingsign.circle.fill")
                                .font(BrandSymbolFont.symbol(22))
                                .foregroundStyle(.gsBrandPrimary)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            Text("Set up your budget")
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextPrimary)
                                .lineLimit(1)
                            Text("Track spending and stay on target")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: AppSpacing.smallSpacing)
                        Image(systemName: "chevron.right")
                            .font(BrandSymbolFont.symbol(12))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set up budget. Opens Insights tab.")
            }
        }
    }
}

// MARK: - Activity Metrics Card

struct ActivityMetricsCard: View {
    let viewModel: DashboardViewModel
    var currencyCode: String = "GBP"

    private var hasData: Bool {
        viewModel.mostPurchasedItem != nil || viewModel.wasteItemCount > 0
    }

    var body: some View {
        if hasData {
            DashboardCard(accentColor: .gsBrandPrimary) {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(BrandSymbolFont.symbol(17))
                            .foregroundStyle(.gsBrandPrimary)
                        Text("Activity")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                    }

                    // Most Purchased
                    if let item = viewModel.mostPurchasedItem {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(.gsBrandPrimary.opacity(0.12))
                                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                                Image(systemName: "bag.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                Text("Most purchased")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                    .lineLimit(1)
                                Text("\(item)")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            Text("\(viewModel.mostPurchasedCount)x")
                                .font(BrandFont.mono(16))
                                .foregroundStyle(.gsBrandPrimary)
                                .padding(.horizontal, AppSpacing.smallSpacing)
                                .padding(.vertical, AppSpacing.compactGap)
                                .background(.gsBrandPrimary.opacity(0.12))
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // Waste this month
                    HStack(spacing: AppSpacing.rowSpacing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(viewModel.wasteItemCount > 0 ? .gsDanger.opacity(0.12) : .gsSuccess.opacity(0.12))
                                .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                            Image(systemName: viewModel.wasteItemCount > 0 ? "trash.fill" : "leaf.fill")
                                .font(BrandSymbolFont.symbol(17))
                                .foregroundStyle(viewModel.wasteItemCount > 0 ? .gsDanger : .gsSuccess)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            Text("Waste this month")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                                .lineLimit(1)
                            if viewModel.wasteItemCount > 0 {
                                Text("\(viewModel.wasteItemCount) item\(viewModel.wasteItemCount == 1 ? "" : "s")")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                                    .lineLimit(1)
                            } else {
                                Text("Zero waste")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsSuccess)
                                    .lineLimit(1)
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        if viewModel.wasteTotalMinor > 0 {
                            Text(viewModel.wasteTotalMinor.currencyFormatted(currencyCode: currencyCode))
                                .font(BrandFont.semiBold(15))
                                .foregroundStyle(.gsDanger)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // Most Wasted Item
                    if let wastedItem = viewModel.mostWastedItem, viewModel.mostWastedCount > 1 {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(.gsDanger.opacity(0.12))
                                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsDanger)
                            }
                            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                Text("Most wasted")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                    .lineLimit(1)
                                Text(wastedItem)
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            Text("\(viewModel.mostWastedCount)x")
                                .font(BrandFont.mono(16))
                                .foregroundStyle(.gsDanger)
                                .padding(.horizontal, AppSpacing.smallSpacing)
                                .padding(.vertical, AppSpacing.compactGap)
                                .background(.gsDanger.opacity(0.12))
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Quick Action Navigation

enum DashboardQuickAction: Identifiable {
    case addItem, shopping, logPurchase
    var id: String {
        switch self {
        case .addItem: return "addItem"
        case .shopping: return "shopping"
        case .logPurchase: return "logPurchase"
        }
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: AppSpacing.compactGap) {
            Image(systemName: "flame.fill")
                .font(BrandSymbolFont.symbol(16))
                .foregroundStyle(count > 0 ? .gsBrandPrimary : .gsTextSecondary)
            Text("\(count)")
                .font(BrandFont.mono(16))
                .foregroundStyle(count > 0 ? .gsBrandPrimary : .gsTextSecondary)
        }
        .padding(.horizontal, AppSpacing.mediumSpacing)
        .padding(.vertical, AppSpacing.denseSpacing)
        .background(
            Capsule()
                .fill(count > 0
                    ? .gsBrandPrimary.opacity(0.15)
                    : .gsSurface)
        )
        .accessibilityLabel("\(count) day streak")
    }
}

// MARK: - Dashboard Card

struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(accentColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardCardSurface()
    }
}
