import SwiftUI

@MainActor
enum DashboardContextualSubtitle {
    static func subtitle(for vm: DashboardViewModel) -> String {
        if vm.healthScore >= 80 { return "Your pantry is in great shape!" }
        if vm.expiringCount > 0 { return "\(vm.expiringCount) item\(vm.expiringCount == 1 ? "" : "s") need attention" }
        if vm.lowStockCount > 0 { return "\(vm.lowStockCount) item\(vm.lowStockCount == 1 ? "" : "s") running low" }
        if vm.totalPantryItems == 0 { return "Add your first item to get started" }
        return "Keep your pantry healthy!"
    }
}

struct DashboardView: View {
    @State var viewModel: DashboardViewModel
    @State var financeVM: FinanceViewModel
    @State private var animateScore = false
    @State private var showPantryReview = false
    @Binding var showSettings: Bool
    var onNavigateToInsights: (() -> Void)?
    var onQuickAction: ((DashboardQuickAction) -> Void)?

    init(
        viewModel: DashboardViewModel,
        financeVM: FinanceViewModel,
        showSettings: Binding<Bool>,
        onNavigateToInsights: (() -> Void)? = nil,
        onQuickAction: ((DashboardQuickAction) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _financeVM = State(initialValue: financeVM)
        _showSettings = showSettings
        self.onNavigateToInsights = onNavigateToInsights
        self.onQuickAction = onQuickAction
    }

    var body: some View {
        NavigationStack {
            DashboardRichLayout(
                viewModel: viewModel,
                financeVM: financeVM,
                animateScore: animateScore,
                showPantryReview: $showPantryReview,
                onNavigateToInsights: onNavigateToInsights,
                onQuickAction: onQuickAction
            )
            .background(Color.appBackground)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable {
                await viewModel.loadData(forceRefresh: true)
                await financeVM.loadData(forceRefresh: true)
            }
            .task {
                await viewModel.loadData()
                await financeVM.loadData()
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animateScore = true
                }
            }
            .sheet(isPresented: $showPantryReview) {
                PantryReviewView(viewModel: PantryReviewViewModel(
                    repository: viewModel.pantryRepository,
                    householdId: viewModel.householdId,
                    staleItems: viewModel.staleItems
                ))
            }
        }
    }
}

// MARK: - Rich Overview Layout

struct DashboardRichLayout: View {
    let viewModel: DashboardViewModel
    let financeVM: FinanceViewModel
    let animateScore: Bool
    @Binding var showPantryReview: Bool
    var onNavigateToInsights: (() -> Void)?
    var onQuickAction: ((DashboardQuickAction) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Hero greeting section
                RichHeroSection(
                    greeting: viewModel.greeting,
                    subtitle: DashboardContextualSubtitle.subtitle(for: viewModel),
                    streak: viewModel.currentStreak,
                    healthScore: viewModel.healthScore,
                    healthLabel: viewModel.healthLabel,
                    animate: animateScore
                )

                VStack(spacing: AppSpacing.rowSpacing) {
                    // 2. Quick actions with icon badges
                    RichQuickActionsRow(onAction: onQuickAction)

                    // 3. Stats row with accent cards
                    HStack(spacing: AppSpacing.mediumSpacing) {
                        AccentCard(
                            icon: "clock.badge.exclamationmark",
                            value: "\(viewModel.expiringCount)",
                            label: "Expiring",
                            accentColor: viewModel.expiringCount > 0 ? Color.errorRed : Color.successGreen
                        )
                        AccentCard(
                            icon: "arrow.down.circle.fill",
                            value: "\(viewModel.lowStockCount)",
                            label: "Low Stock",
                            accentColor: viewModel.lowStockCount > 0 ? Color.warningAmber : Color.successGreen
                        )
                        AccentCard(
                            icon: "cart.badge.plus",
                            value: "\(viewModel.pendingShoppingCount)",
                            label: "To Buy",
                            accentColor: viewModel.pendingShoppingCount > 0 ? Color.accentBlue : Color.successGreen
                        )
                    }

                    // 4. Expiry alert (if any)
                    if !viewModel.expiringItems.isEmpty {
                        NavigationLink {
                            ExpiryCalendarView(items: viewModel.expiringItems)
                        } label: {
                            RichExpiryCard(items: viewModel.expiringItems)
                        }
                        .buttonStyle(.plain)
                    }

                    // 5. Pantry snapshot + Shopping cards
                    VStack(spacing: AppSpacing.rowSpacing) {
                        RichPantryCard(
                            totalItems: viewModel.totalPantryItems,
                            categoriesCount: viewModel.categoriesCount,
                            lowStockCount: viewModel.lowStockCount
                        )

                        HStack(alignment: .top, spacing: AppSpacing.mediumSpacing) {
                            RichShoppingCard(viewModel: viewModel)
                                .frame(minWidth: 0, maxWidth: .infinity)
                            if viewModel.staleCount > 0 {
                                RichNeedsReviewCard(count: viewModel.staleCount) {
                                    showPantryReview = true
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                            }
                        }
                    }

                    // 6. Activity metrics
                    ActivityMetricsCard(viewModel: viewModel, currencyCode: financeVM.currencyCode)

                    // 7. Budget Progress
                    BudgetProgressCard(
                        financeVM: financeVM,
                        onNavigateToInsights: onNavigateToInsights
                    )
                }
                .padding(AppSpacing.screenPadding)
            }
            .padding(.bottom, AppSpacing.sectionSpacing)
        }
    }
}

// MARK: - Rich Layout Components

struct RichHeroSection: View {
    let greeting: String
    let subtitle: String
    let streak: Int
    let healthScore: Int
    let healthLabel: String
    let animate: Bool

    private var scoreColor: Color {
        switch healthScore {
        case 80...100: return Color.successGreen
        case 60..<80: return Color.primaryGreen
        case 40..<60: return Color.warningAmber
        default: return Color.errorRed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.smallSpacing / 2) {
                    Text(greeting)
                        .font(AppFont.greeting)
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                HStack(spacing: AppSpacing.smallSpacing) {
                    StreakBadge(count: streak)
                    Text("\(animate ? healthScore : 0)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                        .padding(.horizontal, AppSpacing.rowSpacing)
                        .padding(.vertical, 6)
                        .background(scoreColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .layoutPriority(1)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                    .fill(scoreColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius)
                    .stroke(scoreColor.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.smallSpacing)
        }
    }
}

struct RichQuickActionsRow: View {
    var onAction: ((DashboardQuickAction) -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            RichQuickActionButton(
                icon: "plus.circle.fill",
                label: "Add Item",
                color: Color.primaryGreen
            ) { onAction?(.addItem) }
            RichQuickActionButton(
                icon: "cart.fill",
                label: "Shopping",
                color: Color.accentBlue
            ) { onAction?(.shopping) }
            RichQuickActionButton(
                icon: "dollarsign.circle.fill",
                label: "Log Purchase",
                color: Color.successGreen
            ) { onAction?(.logPurchase) }
        }
    }
}

struct RichQuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.smallSpacing) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(AppFont.badgeLabel)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.rowSpacing)
            .padding(.horizontal, AppSpacing.smallSpacing)
            .background(color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }
            Text(value)
                .font(AppFont.statValue)
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
        .cardShadow()
    }
}

struct RichExpiryCard: View {
    let items: [PantryItem]

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                    .fill(Color.errorRed.opacity(0.15))
                    .frame(width: AppSpacing.iconSizeLarge, height: AppSpacing.iconSizeLarge)
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(Color.errorRed)
            }
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing / 2) {
                Text("Use It or Lose It")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                Text("\(items.count) item\(items.count == 1 ? "" : "s") expiring soon")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.errorRed.opacity(0.6))
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.errorRed.opacity(0.2), lineWidth: 1)
        )
        .cardShadow()
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
                        .fill(Color.primaryGreen.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "refrigerator.fill")
                        .font(.title3)
                        .foregroundStyle(Color.primaryGreen)
                }
                Text("Pantry")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
            }
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.smallSpacing) {
                    Text("\(totalItems)")
                        .font(AppFont.statValueLarge)
                        .foregroundStyle(Color.primaryText)
                    Text("items")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                HStack(spacing: AppSpacing.mediumSpacing) {
                    Label("\(categoriesCount) categories", systemImage: "folder.fill")
                        .font(AppFont.badgeLabel)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if lowStockCount > 0 {
                        Label("\(lowStockCount) low", systemImage: "arrow.down.circle.fill")
                            .font(AppFont.badgeLabel)
                            .foregroundStyle(Color.warningAmber)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.primaryGreen.opacity(0.15), lineWidth: 1)
        )
        .cardShadow()
    }
}

struct RichShoppingCard: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
            HStack(spacing: AppSpacing.mediumSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                        .fill(Color.accentBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "cart.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentBlue)
                }
                Text("Shopping")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
            }
            if viewModel.shoppingTotal > 0 {
                Text("\(viewModel.shoppingCompleted)/\(viewModel.shoppingTotal)")
                    .font(AppFont.statValueMedium)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                ProgressView(value: viewModel.completionPercentage, total: 100)
                    .tint(Color.accentBlue)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            } else {
                Text("No items")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.accentBlue.opacity(0.15), lineWidth: 1)
        )
        .cardShadow()
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
                            .fill(Color.warningAmber.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundStyle(Color.warningAmber)
                    }
                    Text("Review")
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                }
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(AppFont.statValueMedium)
                    .foregroundStyle(Color.primaryText)
                Text("need attention")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.warningAmber.opacity(0.15), lineWidth: 1)
            )
            .cardShadow()
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
                    .font(.title3)
                    .foregroundStyle(color)
            }
            Text(value)
                .font(AppFont.statValueMedium)
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
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
        case .green: return Color.successGreen
        case .amber: return Color.warningAmber
        case .red: return Color.errorRed
        }
    }

    var body: some View {
        if financeVM.hasBudget {
            DashboardCard(accentColor: budgetColor) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sterlingsign.circle.fill")
                            .foregroundStyle(budgetColor)
                        Text("Budget")
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
                        Spacer(minLength: 8)
                        Text(financeVM.currentPeriodLabel)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack {
                        Text("Spent")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        Text(financeVM.totalSpentMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
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
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                            } else {
                                Text("\(abs(financeVM.budgetRemainingMinor).currencyFormatted(currencyCode: financeVM.currencyCode)) over")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.errorRed)
                            }
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text("of \(financeVM.budgetAmountMinor.currencyFormatted(currencyCode: financeVM.currencyCode))")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        } else if let onNavigate = onNavigateToInsights {
            DashboardCard(accentColor: Color.primaryGreen) {
                Button(action: onNavigate) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(Color.primaryGreen.opacity(0.12))
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            Image(systemName: "sterlingsign.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.primaryGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set up your budget")
                                .font(AppFont.button)
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(1)
                            Text("Track spending and stay on target")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
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
            DashboardCard(accentColor: Color.primaryGreen) {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.primaryGreen)
                        Text("Activity")
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
                    }

                    // Most Purchased
                    if let item = viewModel.mostPurchasedItem {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(Color.accentBlue.opacity(0.12))
                                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                                Image(systemName: "bag.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.accentBlue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Most Purchased")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(1)
                                Text("\(item)")
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            Text("\(viewModel.mostPurchasedCount)x")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentBlue.opacity(0.12))
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // Waste this month
                    HStack(spacing: AppSpacing.rowSpacing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                .fill(viewModel.wasteItemCount > 0 ? Color.errorRed.opacity(0.12) : Color.successGreen.opacity(0.12))
                                .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                            Image(systemName: viewModel.wasteItemCount > 0 ? "trash.fill" : "leaf.fill")
                                .font(.body)
                                .foregroundStyle(viewModel.wasteItemCount > 0 ? Color.errorRed : Color.successGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waste This Month")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(1)
                            if viewModel.wasteItemCount > 0 {
                                Text("\(viewModel.wasteItemCount) item\(viewModel.wasteItemCount == 1 ? "" : "s")")
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                            } else {
                                Text("Zero waste!")
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.successGreen)
                                    .lineLimit(1)
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        if viewModel.wasteTotalMinor > 0 {
                            Text(viewModel.wasteTotalMinor.currencyFormatted(currencyCode: currencyCode))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.errorRed)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // Most Wasted Item
                    if let wastedItem = viewModel.mostWastedItem, viewModel.mostWastedCount > 1 {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(Color.warningAmber.opacity(0.12))
                                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.warningAmber)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Most Wasted")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(1)
                                Text(wastedItem)
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            Text("\(viewModel.mostWastedCount)x")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.warningAmber)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.warningAmber.opacity(0.12))
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
        HStack(spacing: AppSpacing.smallSpacing / 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(count > 0 ? Color.warningAmber : Color.secondaryText)
            Text("\(count)")
                .font(AppFont.badgeValue)
                .foregroundStyle(count > 0 ? Color.warningAmber : Color.secondaryText)
        }
        .padding(.horizontal, AppSpacing.mediumSpacing)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(count > 0
                    ? Color.warningAmber.opacity(0.15)
                    : Color.cardBackground)
        )
        .accessibilityLabel("\(count) day streak")
    }
}

// MARK: - Dashboard Card

struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content
    var accentColor: Color?

    init(accentColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        Group {
            if let accent = accentColor {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 4)
                    content
                        .padding(AppSpacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                content
                    .padding(AppSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }
}
