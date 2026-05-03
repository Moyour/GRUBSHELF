import SwiftUI

// MARK: - Glass Design System Helpers

/// Frosted-glass card surface inspired by Apple's visionOS / iOS 18 material style.
/// Replaces the opaque `dashboardCardSurface()` with translucent material + subtle border.
private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppSpacing.cardRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.gsSurface.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = AppSpacing.cardRadius) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Dashboard Layout

/// Drop-in alternative to `DashboardRichLayout` using Apple-style glass/material cards.
/// Wire this into `DashboardView.body` in place of `DashboardRichLayout` to preview the look.
struct DashboardGlassLayout: View {
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
            VStack(spacing: AppSpacing.rowSpacing) {
                // 1. Glass hero
                glassHero

                // 2. Streak bar
                if viewModel.totalPantryItems > 0 {
                    glassStreakBar
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                // 3. Quick actions
                glassQuickActions
                    .padding(.horizontal, AppSpacing.screenPadding)

                // 4. Insights carousel
                InsightsCarousel(
                    viewModel: viewModel,
                    financeVM: financeVM,
                    onNavigateToInsights: onNavigateToInsights,
                    onNavigateToPantry: onNavigateToPantry,
                    onNavigateToShopping: onNavigateToShopping
                )

                // 5-9. Cards
                VStack(spacing: AppSpacing.rowSpacing) {
                    glassAccentCards

                    ContextualAlertsSection(
                        expiringItems: viewModel.expiringItems,
                        lowStockCount: viewModel.lowStockCount,
                        onNavigateToPantry: onNavigateToPantry
                    )

                    glassPantryShoppingRow

                    glassActivityCard

                    glassBudgetCard
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    // MARK: - Glass Hero

    private var glassHero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                Text(viewModel.overviewHeadline)
                    .font(BrandFont.bold(24))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                Text(DashboardContextualSubtitle.subtitle(for: viewModel))
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Spacer()
                ZStack {
                    // Outer — Pantry Health
                    ringTrack(diameter: 160, color: .gsBrandPrimary)
                    ringArc(diameter: 160, fraction: animateScore ? CGFloat(viewModel.healthScore) / 100.0 : 0, color: .gsBrandPrimary)

                    // Middle — Budget
                    if financeVM.hasBudget {
                        ringTrack(diameter: 120, color: .gsBrandPrimary)
                        ringArc(diameter: 120, fraction: animateScore ? CGFloat(1.0 - financeVM.spendProgress) : 0, color: .gsBrandPrimary)
                    }

                    // Inner — Waste
                    let wasteColor: Color = viewModel.wasteItemCount == 0 ? .gsSuccess : .gsDanger
                    let wasteFrac: CGFloat = animateScore ? (viewModel.wasteItemCount == 0 ? 1.0 : max(0, 1.0 - CGFloat(viewModel.wasteItemCount) / 10.0)) : 0
                    ringTrack(diameter: 80, color: wasteColor)
                    ringArc(diameter: 80, fraction: wasteFrac, color: wasteColor)

                    Text("\(animateScore ? viewModel.healthScore : 0)")
                        .font(BrandFont.bold(30))
                        .foregroundStyle(.gsTextPrimary)
                        .contentTransition(.numericText())
                }
                .frame(width: 180, height: 180)
                .animation(.easeOut(duration: 1.0), value: animateScore)
                Spacer()
            }

            HStack(spacing: AppSpacing.rowSpacing) {
                legendDot(color: .gsBrandPrimary, label: "Pantry")
                if financeVM.hasBudget {
                    legendDot(color: .gsBrandPrimary, label: "Budget")
                }
                legendDot(color: viewModel.wasteItemCount == 0 ? .gsSuccess : .gsDanger, label: "Waste")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.cardPadding)
        .glassCard(cornerRadius: AppSpacing.heroRadius)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.smallSpacing)
    }

    // MARK: - Glass Streak Bar

    private var glassStreakBar: some View {
        let level = viewModel.currentStreak / 7 + 1
        let weekProgress = viewModel.currentStreak % 7

        return HStack(spacing: AppSpacing.mediumSpacing) {
            HStack(spacing: AppSpacing.compactGap) {
                Image(systemName: "flame.fill")
                    .font(BrandSymbolFont.symbol(16))
                    .foregroundStyle(viewModel.currentStreak > 0 ? .gsBrandPrimary : .gsTextSecondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.currentStreak > 0)
                Text("\(viewModel.currentStreak)")
                    .font(BrandFont.mono(16))
                    .foregroundStyle(viewModel.currentStreak > 0 ? .gsBrandPrimary : .gsTextSecondary)
            }

            HStack(spacing: AppSpacing.compactGap) {
                ForEach(0..<7, id: \.self) { day in
                    Circle()
                        .fill(day < weekProgress ? .gsBrandPrimary : .gsBrandPrimary.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

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
        .glassCard()
    }

    // MARK: - Glass Quick Actions

    private var glassQuickActions: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            glassActionButton(icon: "plus.circle.fill", label: "Add item", color: .gsBrandPrimary) {
                onQuickAction?(.addItem)
            }
            glassActionButton(icon: "cart.fill", label: "Shopping", color: .gsBrandPrimary) {
                onQuickAction?(.shopping)
            }
            glassActionButton(icon: "dollarsign.circle.fill", label: "Log purchase", color: .gsBrandPrimary) {
                onQuickAction?(.logPurchase)
            }
        }
    }

    private func glassActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.smallSpacing) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                    Image(systemName: icon)
                        .font(BrandSymbolFont.symbol(17))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(BrandFont.semiBold(13))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.rowSpacing)
            .padding(.horizontal, AppSpacing.smallSpacing)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Glass Accent Cards

    private var glassAccentCards: some View {
        HStack(spacing: AppSpacing.mediumSpacing) {
            glassAccent(
                icon: "clock.badge.exclamationmark",
                value: "\(viewModel.expiringCount)",
                label: "Expiring",
                color: viewModel.expiringCount > 0 ? .gsWarning : .gsTextSecondary
            )
            glassAccent(
                icon: "arrow.down.circle.fill",
                value: "\(viewModel.lowStockCount)",
                label: "Low Stock",
                color: viewModel.lowStockCount > 0 ? .gsWarning : .gsTextSecondary
            )
            glassAccent(
                icon: "cart.badge.plus",
                value: "\(viewModel.pendingShoppingCount)",
                label: "To Buy",
                color: viewModel.pendingShoppingCount > 0 ? .gsBrandPrimary : .gsTextSecondary
            )
        }
    }

    private func glassAccent(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.mediumSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(color.opacity(0.15))
                    .frame(width: AppSpacing.iconSizeLarge, height: AppSpacing.iconSizeLarge)
                Image(systemName: icon)
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(color)
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
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.cardPadding)
        .glassCard()
    }

    // MARK: - Glass Pantry + Shopping Row

    private var glassPantryShoppingRow: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            Button { onNavigateToPantry?() } label: {
                glassPantryCard
            }
            .buttonStyle(.plain)

            HStack(alignment: .top, spacing: AppSpacing.mediumSpacing) {
                Button { onNavigateToShopping?() } label: {
                    glassShoppingCard
                }
                .buttonStyle(.plain)
                .frame(minWidth: 0, maxWidth: .infinity)

                if viewModel.staleCount > 0 {
                    glassReviewCard
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
            }
        }
    }

    private var glassPantryCard: some View {
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
                    Text("\(viewModel.totalPantryItems)")
                        .font(BrandFont.bold(22))
                        .foregroundStyle(.gsTextPrimary)
                    Text("items")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }
                HStack(spacing: AppSpacing.mediumSpacing) {
                    Label("\(viewModel.categoriesCount) categories", systemImage: "folder.fill")
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if viewModel.lowStockCount > 0 {
                        Label("\(viewModel.lowStockCount) low", systemImage: "arrow.down.circle.fill")
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
        .glassCard()
    }

    private var glassShoppingCard: some View {
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
        .glassCard()
    }

    private var glassReviewCard: some View {
        Button {
            showPantryReview = true
        } label: {
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
                Text("\(viewModel.staleCount) item\(viewModel.staleCount == 1 ? "" : "s")")
                    .font(BrandFont.bold(22))
                    .foregroundStyle(.gsTextPrimary)
                Text("need attention")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Glass Activity Card

    private var glassActivityCard: some View {
        let hasData = viewModel.mostPurchasedItem != nil || viewModel.wasteItemCount > 0

        return Group {
            if hasData {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(BrandSymbolFont.symbol(17))
                            .foregroundStyle(.gsBrandPrimary)
                        Text("Activity")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                    }

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
                                Text(item)
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

                    HStack(spacing: AppSpacing.rowSpacing) {
                        let wasteColor: Color = viewModel.wasteItemCount > 0 ? .gsDanger : .gsSuccess
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(wasteColor.opacity(0.12))
                                .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                            Image(systemName: viewModel.wasteItemCount > 0 ? "trash.fill" : "leaf.fill")
                                .font(BrandSymbolFont.symbol(17))
                                .foregroundStyle(wasteColor)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            Text("Waste this month")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                            if viewModel.wasteItemCount > 0 {
                                Text("\(viewModel.wasteItemCount) item\(viewModel.wasteItemCount == 1 ? "" : "s")")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } else {
                                Text("Zero waste")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsSuccess)
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        if viewModel.wasteTotalMinor > 0 {
                            Text(viewModel.wasteTotalMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                                .font(BrandFont.semiBold(15))
                                .foregroundStyle(.gsDanger)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    // MARK: - Glass Budget Card

    private var glassBudgetCard: some View {
        let budgetColor: Color = {
            switch financeVM.budgetColor {
            case .green: return .gsBrandPrimary
            case .amber: return .gsWarning
            case .red: return .gsDanger
            }
        }()

        return Group {
            if financeVM.hasBudget {
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

                    HStack(spacing: AppSpacing.smallSpacing) {
                        if financeVM.budgetRemainingMinor >= 0 {
                            Text("\(financeVM.budgetRemainingMinor.currencyFormatted(currencyCode: financeVM.currencyCode)) remaining")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        } else {
                            Text("\(abs(financeVM.budgetRemainingMinor).currencyFormatted(currencyCode: financeVM.currencyCode)) over")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        Spacer(minLength: AppSpacing.smallSpacing)
                        Text("of \(financeVM.budgetAmountMinor.currencyFormatted(currencyCode: financeVM.currencyCode))")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            } else if let onNavigate = onNavigateToInsights {
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
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    // MARK: - Ring Helpers

    private let ringWidth: CGFloat = 12

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
