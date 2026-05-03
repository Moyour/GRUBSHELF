import SwiftUI

struct InsightsView: View {
    @State var insightsVM: InsightsViewModel
    @State var financeVM: FinanceViewModel
    @State private var showBudgetSettings = false
    @State private var showLogPurchaseSheet = false

    var body: some View {
        NavigationStack {
            unifiedExpenseContent
            .frame(maxHeight: .infinity)
            .background(.gsBackground)
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await insightsVM.loadData()
                await financeVM.loadData()
            }
            .refreshable {
                await insightsVM.loadData(forceRefresh: true)
                await financeVM.loadData(forceRefresh: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        PrimaryToolbarIconButton(
                            systemImage: "dollarsign.circle.fill",
                            accessibilityLabel: "Log purchase",
                            accessibilityHint: "Add a purchase manually",
                            action: { showLogPurchaseSheet = true }
                        )
                        PrimaryToolbarIconButton(
                            systemImage: "gearshape.circle",
                            accessibilityLabel: "Budget and currency settings",
                            accessibilityHint: "Change budget, period, and currency",
                            action: { showBudgetSettings = true }
                        )
                    }
                }
            }
            .sheet(isPresented: $showBudgetSettings, onDismiss: {
                Task { await financeVM.loadData(forceRefresh: true) }
            }) {
                BudgetSettingsSheet(userId: financeVM.userId)
            }
            .sheet(isPresented: $showLogPurchaseSheet, onDismiss: {
                Task { await financeVM.loadData(forceRefresh: true) }
            }) {
                LogPurchaseSheet(financeVM: financeVM)
            }
            .alert("Add trip cost", isPresented: .init(
                get: { financeVM.tripToLog != nil },
                set: { if !$0 { financeVM.tripToLog = nil; financeVM.retroactiveCostText = "" } }
            )) {
                TextField("Amount", text: $financeVM.retroactiveCostText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    let costText = financeVM.retroactiveCostText
                    let trip = financeVM.tripToLog
                    Task { await financeVM.saveRetroactiveCost(trip: trip, costText: costText) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let trip = financeVM.tripToLog {
                    Text("How much did you spend on \(trip.date.formatted(date: .abbreviated, time: .omitted))?")
                }
            }
            .tint(.gsBrandPrimary)
        }
    }

    // MARK: - Unified expense

    private var unifiedExpenseContent: some View {
        Group {
            if !financeVM.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        if !financeVM.hasBudget {
                            budgetSetupCard
                        } else {
                            // 1. Compact budget hero
                            expenseCompactHero

                            // 2. Quick stats row
                            expenseQuickStatsRow

                            // 3. Unlogged trips banner
                            if !financeVM.unloggedTrips.isEmpty {
                                unloggedTripsBanner
                            }

                            // 4. Spending section (metric rows)
                            expenseSpendingSection

                            // 5. Waste & Efficiency section
                            expenseWasteSection
                        }

                        // 6. Spend heatmap
                        if financeVM.hasBudget {
                            spendHeatmapCard
                        }

                        // 7. Category breakdown
                        analyticsCardView(for: .categoryBreakdown)

                        // 8. Smart tips
                        if !insightsVM.smartTips.isEmpty {
                            SmartTipsSection(tips: insightsVM.smartTips)
                        }

                        // 9. Achievements
                        AchievementsCard(viewModel: insightsVM)
                    }
                    .padding(AppSpacing.screenPadding)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Expense Compact Hero (Concept C style)

    private var expenseCompactHero: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    Text(financeVM.budgetPeriodKindLabel)
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(financeVM.totalSpentMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(BrandFont.bold(26))
                        .foregroundStyle(.gsTextPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.35), value: financeVM.totalSpentMinor)
                    Text("/ \(financeVM.budgetAmountMinor.currencyFormatted(currencyCode: financeVM.currencyCode))")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.compactGap) {
                    if financeVM.budgetRemainingMinor >= 0 {
                        Text(financeVM.budgetRemainingMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(BrandFont.bold(20))
                            .foregroundStyle(heroColor)
                    } else {
                        Text(abs(financeVM.budgetRemainingMinor).currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(BrandFont.bold(20))
                            .foregroundStyle(heroColor)
                    }
                    Text(financeVM.budgetRemainingMinor >= 0 ? "remaining" : "over budget")
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                Capsule()
                    .fill(Color.gsSurface.opacity(0.6))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(heroColor)
                            .frame(width: max(0, geo.size.width * min(financeVM.spendProgress, 1.0)), height: 4)
                            .animation(.easeOut(duration: 0.35), value: financeVM.spendProgress)
                    }
            }
            .frame(height: 4)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardSurface()
    }

    // MARK: - Quick Stats Row

    private var expenseQuickStatsRow: some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            ExpenseQuickStatCard(
                emoji: "🛒",
                value: "\(financeVM.trips.count)",
                label: "Trips"
            )
            ExpenseQuickStatCard(
                emoji: "💷",
                value: insightsVM.averageTripCostMinor > 0
                    ? insightsVM.averageTripCostMinor.currencyFormatted(currencyCode: financeVM.currencyCode)
                    : "—",
                label: "Avg. trip"
            )
            ExpenseQuickStatCard(
                emoji: "🍃",
                value: insightsVM.wasteEstimate > 0
                    ? insightsVM.wasteEstimate.currencyFormatted(currencyCode: financeVM.currencyCode)
                    : "—",
                label: "Wasted"
            )
        }
    }

    // MARK: - Spending Section (Concept B metric rows)

    private var expenseSpendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            ExpenseSectionLabel(title: "Spending")

            ExpenseMetricRow(
                emoji: "🛒",
                iconColor: .gsBrandPrimary,
                title: "Shopping Trips",
                subtitle: "This period",
                value: "\(financeVM.trips.count)"
            )
            ExpenseMetricRow(
                emoji: "💷",
                iconColor: .gsWarning,
                title: "Average Trip Cost",
                subtitle: "Per run",
                value: insightsVM.averageTripCostMinor > 0
                    ? insightsVM.averageTripCostMinor.currencyFormatted(currencyCode: financeVM.currencyCode)
                    : "—"
            )
            ExpenseMetricRow(
                emoji: "🥫",
                iconColor: .gsBrandPrimary,
                title: "Pantry Value",
                subtitle: "Estimated total",
                value: insightsVM.totalPantryValueMinor > 0
                    ? insightsVM.totalPantryValueMinor.currencyFormatted(currencyCode: financeVM.currencyCode)
                    : "—"
            )
            ExpenseMetricRow(
                emoji: "📊",
                iconColor: .gsBrandPrimary,
                title: "Effective Value",
                subtitle: "Spent − wasted",
                value: financeVM.totalSpentMinor > 0
                    ? financeVM.effectiveValueMinor.currencyFormatted(currencyCode: financeVM.currencyCode)
                    : "—"
            )
        }
    }

    // MARK: - Waste & Efficiency Section

    private var expenseWasteSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            ExpenseSectionLabel(title: "Waste & Efficiency")

            WasteTrackerCard(
                currentWaste: insightsVM.wasteEstimate,
                lastMonthWaste: insightsVM.lastMonthWaste,
                direction: insightsVM.wasteChangeDirection,
                expiredCount: insightsVM.expiredCount,
                currencyCode: financeVM.currencyCode
            )

            analyticsCardView(for: .shoppingEfficiency)
        }
    }

    private var budgetSetupCard: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            Image(systemName: Locale.currencyCircleSymbolName(for: financeVM.currencyCode))
                .font(BrandSymbolFont.symbol(34, weight: .bold))
                .foregroundStyle(.gsBrandPrimary.opacity(0.4))

            Text("Set up your budget")
                .font(BrandFont.semiBold(18))
                .foregroundStyle(.gsTextPrimary)

            Text("Configure your budget period and amount to see this month, trends, and daily spend. Insights below work either way.")
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showBudgetSettings = true
            } label: {
                Text("Set up budget")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.minTouchTarget)
                    .background(.gsBrandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .padding(.top, AppSpacing.smallSpacing)

            Button {
                showLogPurchaseSheet = true
            } label: {
                Text("Or log a quick purchase")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsBrandPrimary)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.smallSpacing)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .dashboardCardSurface()
    }

    private var heroColor: Color {
        switch financeVM.budgetColor {
        case .green: return .gsBrandPrimary
        case .amber: return .gsWarning
        case .red: return .gsDanger
        }
    }

    // MARK: - Heatmap

    private var spendHeatmapCard: some View {
        DashboardCard {
            ExpenseSpendHeatmapCard(
                cells: financeVM.heatmapDayCells,
                budgetPeriod: financeVM.financeSettings?.budgetPeriod ?? .monthly,
                currencyCode: financeVM.currencyCode
            )
        }
    }

    // MARK: - Unlogged Trips Banner

    private var unloggedTripsBanner: some View {
        VStack(spacing: AppSpacing.smallSpacing) {
            ForEach(financeVM.unloggedTrips) { trip in
                HStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(BrandSymbolFont.symbol(18))
                        .foregroundStyle(.gsBrandPrimary)
                    Text("Trip on \(trip.date.formatted(date: .abbreviated, time: .omitted)) — cost not logged.")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextPrimary)
                    Spacer()
                    Button("Add") {
                        financeVM.tripToLog = trip
                    }
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsBrandPrimary)
                }
                .padding(AppSpacing.cardPadding)
                .background(.gsBrandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            }
        }
    }

    private func insightsExpiringDateColor(for state: ItemState) -> Color {
        switch state {
        case .expired: return .gsDanger
        case .expiringSoon: return .gsWarning
        default: return .gsTextSecondary
        }
    }

    @ViewBuilder
    private func analyticsCardView(for card: AnalyticsCard) -> some View {
        switch card {
        case .smartTips:
            if !insightsVM.smartTips.isEmpty {
                SmartTipsSection(tips: insightsVM.smartTips)
            }
        case .wasteTracker:
            WasteTrackerCard(
                currentWaste: insightsVM.wasteEstimate,
                lastMonthWaste: insightsVM.lastMonthWaste,
                direction: insightsVM.wasteChangeDirection,
                expiredCount: insightsVM.expiredCount,
                currencyCode: financeVM.currencyCode
            )
        case .monthlySpend:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Monthly Spend", systemImage: "chart.bar.fill")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    if insightsVM.monthlySpendData.isEmpty || insightsVM.monthlySpendData.allSatisfy({ $0.amount == 0 }) {
                        EmptyDataView(message: "Start logging purchases to see spending trends")
                    } else {
                        ExpenseMonthlySpendChart(items: insightsVM.monthlySpendData)
                    }
                }
            }
        case .categoryBreakdown:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Items by Category", systemImage: "tag.fill")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    if insightsVM.categoryBreakdown.isEmpty {
                        EmptyDataView(message: "Add pantry items to see category breakdown")
                    } else {
                        CategoryPantryBreakdownVisual(rows: insightsVM.categoryBreakdown)
                    }
                }
            }
        case .mostPurchased:
            if !insightsVM.mostPurchasedItems.isEmpty {
                ItemFrequencyCard(title: "Most Purchased", icon: "repeat", items: insightsVM.mostPurchasedItems)
            }
        case .leastPurchased:
            if !insightsVM.leastPurchasedItems.isEmpty {
                ItemFrequencyCard(title: "Least Purchased", icon: "arrow.down.circle", items: insightsVM.leastPurchasedItems)
            }
        case .mostWasted:
            if !insightsVM.mostWastedItems.isEmpty {
                ItemSpendCard(title: "Most Wasted", icon: "trash.fill", items: insightsVM.mostWastedItems, currencyCode: financeVM.currencyCode)
            }
        case .leastWasted:
            if !insightsVM.leastWastedItems.isEmpty {
                ItemSpendCard(title: "Least Wasted", icon: "hand.thumbsup.fill", items: insightsVM.leastWastedItems, currencyCode: financeVM.currencyCode)
            }
        case .mostSpentByItem:
            if !insightsVM.mostSpentByItem.isEmpty {
                ItemSpendCard(title: "Most Spent by Item", icon: "sterlingsign.circle.fill", items: insightsVM.mostSpentByItem, currencyCode: financeVM.currencyCode)
            }
        case .mostSpentByCategory:
            if !insightsVM.mostSpentByCategory.isEmpty {
                CategorySpendCard(items: insightsVM.mostSpentByCategory, currencyCode: financeVM.currencyCode)
            }
        case .shoppingEfficiency:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Shopping Efficiency", systemImage: "chart.line.uptrend.xyaxis")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    HStack(spacing: AppSpacing.sectionSpacing) {
                        EfficiencyStat(value: "\(insightsVM.shoppingCompleted)", label: "Completed", color: .gsBrandPrimary)
                        EfficiencyStat(value: "\(insightsVM.shoppingTotal - insightsVM.shoppingCompleted)", label: "Pending", color: .gsBrandPrimary)
                        EfficiencyStat(value: "\(Int(insightsVM.shoppingCompletionRate))%", label: "Rate",
                            color: .gsBrandPrimary)
                    }
                    if insightsVM.shoppingTotal > 0 {
                        ProgressView(value: insightsVM.shoppingCompletionRate, total: 100)
                            .tint(.gsBrandPrimary)
                    }
                }
            }
        case .lowStockCount:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Low Stock", systemImage: "cart.badge.plus")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    Text("\(insightsVM.lowStockCount) item\(insightsVM.lowStockCount == 1 ? "" : "s") running low")
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextSecondary)
                }
            }
        case .expiringSoon:
            if !insightsVM.expiringItems.isEmpty {
                DashboardCard {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                        ForEach(insightsVM.expiringItems.prefix(5)) { item in
                            HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                                Text(item.name)
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                                VStack(alignment: .trailing, spacing: AppSpacing.microGap) {
                                    StatusBadgeView(status: StatusBadgeView.Status(itemState: item.state))
                                        .fixedSize(horizontal: true, vertical: true)
                                    if let expiry = item.expiryDate {
                                        Text(expiry, style: .date)
                                            .font(BrandFont.regular(14))
                                            .foregroundStyle(insightsExpiringDateColor(for: item.state))
                                    }
                                }
                            }
                            if item.id != insightsVM.expiringItems.prefix(5).last?.id { Divider() }
                        }
                    }
                }
            }
        case .pantryValue:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Pantry Value", systemImage: "dollarsign.circle.fill")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    Text(insightsVM.totalPantryValueMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(BrandFont.bold(26))
                        .foregroundStyle(.gsBrandPrimary)
                }
            }
        case .averageTripCost:
            if insightsVM.averageTripCostMinor > 0 {
                DashboardCard {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Label("Average Trip Cost", systemImage: "cart.fill")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                        Text(insightsVM.averageTripCostMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(BrandFont.bold(26))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                }
            }
        case .achievements:
            AchievementsCard(viewModel: insightsVM)
        }
    }
}

// MARK: - Expense Quick Stat Card (Concept C)

private struct ExpenseQuickStatCard: View {
    let emoji: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: AppSpacing.compactGap) {
            Text(emoji)
                .font(.system(size: 20))
            Text(value)
                .font(BrandFont.bold(17))
                .foregroundStyle(.gsTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(BrandFont.regular(12))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.rowSpacing)
        .padding(.horizontal, AppSpacing.smallSpacing)
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(Color.gsBorder.opacity(0.45), lineWidth: 0.5)
        )
    }
}

// MARK: - Expense Metric Row (Concept B)

private struct ExpenseMetricRow: View {
    let emoji: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.iconRadius, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                Text(emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(title)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(BrandFont.bold(17))
                .foregroundStyle(.gsTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardSurface()
    }
}

// MARK: - Expense Section Label

private struct ExpenseSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(BrandFont.semiBold(14))
            .foregroundStyle(.gsTextSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Item Frequency Card

struct ItemFrequencyCard: View {
    let title: String
    let icon: String
    let items: [ItemFrequency]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                Label(title, systemImage: icon)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .truncationMode(.tail)
                        Spacer()
                        Text("\(item.count)x")
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(.gsTextSecondary)
                            .padding(.horizontal, AppSpacing.smallSpacing)
                            .padding(.vertical, AppSpacing.compactGap)
                            .background(.gsBrandPrimary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Item Spend Card

struct ItemSpendCard: View {
    let title: String
    let icon: String
    let items: [ItemSpend]
    var currencyCode: String = "GBP"

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                Label(title, systemImage: icon)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .truncationMode(.tail)
                        Spacer()
                        Text(item.amountMinor.currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Category Spend Card

struct CategorySpendCard: View {
    let items: [CategorySpendAmount]
    var currencyCode: String = "GBP"

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                Label("Most Spent by Category", systemImage: "chart.bar.horizontal")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                CategoryCurrencyHorizontalBars(rows: items, currencyCode: currencyCode)
            }
        }
    }
}

// MARK: - Smart Tips Section

struct SmartTipsSection: View {
    let tips: [SmartTip]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                HStack(alignment: .center) {
                    Label("Smart Tips", systemImage: "lightbulb.fill")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    Spacer()
                    Text("\(tips.count)")
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextSecondary)
                        .padding(.horizontal, AppSpacing.smallSpacing)
                        .padding(.vertical, AppSpacing.compactGap)
                        .background(Color.gsSurface)
                        .clipShape(Capsule())
                        .accessibilityLabel(String(localized: "\(tips.count) tips"))
                }

                VStack(spacing: AppSpacing.smallSpacing) {
                    ForEach(tips) { tip in
                        HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                Circle()
                                    .fill(tipColor(tip.color).opacity(0.14))
                                    .frame(width: 44, height: 44)
                                Image(systemName: tip.icon)
                                    .font(BrandSymbolFont.symbol(20))
                                    .foregroundStyle(tipColor(tip.color))
                            }

                            Text(tip.message)
                                .font(BrandFont.regular(16))
                                .foregroundStyle(.gsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                                .fill(Color.gsSurface.opacity(0.55))
                        )
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tipColor(tip.color))
                                .frame(width: 4)
                                .padding(.vertical, AppSpacing.smallSpacing)
                                .padding(.leading, 0)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    }
                }
            }
        }
    }

    private func tipColor(_ color: SmartTip.TipColor) -> Color {
        switch color {
        case .warning: return .gsTextSecondary
        case .success: return .gsBrandPrimary
        case .info: return .gsBrandPrimary
        }
    }
}

// MARK: - Waste Tracker Card

struct WasteTrackerCard: View {
    let currentWaste: Int
    let lastMonthWaste: Int
    let direction: InsightsViewModel.WasteDirection
    let expiredCount: Int
    var currencyCode: String = "GBP"

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                HStack {
                    Label("Waste Tracker", systemImage: "trash.circle.fill")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    Spacer()
                    directionBadge
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sectionSpacing) {
                    VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                        Text("This month")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                        Text(currentWaste.currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.bold(30))
                            .foregroundStyle(currentWaste > 0 ? .gsTextSecondary : .gsBrandPrimary)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                        Text("Last month")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                        Text(lastMonthWaste.currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.semiBold(22))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }

                WasteMonthComparisonChart(
                    currentMinor: currentWaste,
                    lastMinor: lastMonthWaste,
                    currencyCode: currencyCode
                )

                if expiredCount > 0 {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.gsTextSecondary)
                            .font(BrandSymbolFont.symbol(12))
                        Text("\(expiredCount) item\(expiredCount == 1 ? "" : "s") expired this month")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                    }
                } else {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.gsBrandPrimary)
                            .font(BrandSymbolFont.symbol(12))
                        Text("No waste — nice")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var directionBadge: some View {
        switch direction {
        case .down:
            Label("Improving", systemImage: "arrow.down.right")
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsBrandPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(.gsBrandPrimary.opacity(0.12))
                .clipShape(Capsule())
        case .up:
            Label("Increasing", systemImage: "arrow.up.right")
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(.gsTextSecondary.opacity(0.12))
                .clipShape(Capsule())
        case .flat:
            Label("Stable", systemImage: "arrow.right")
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(.gsSurface)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Efficiency Stat

struct EfficiencyStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.compactGap) {
            Text(value)
                .font(BrandFont.bold(22))
                .foregroundStyle(color)
            Text(label)
                .font(BrandFont.semiBold(13))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievements Card

struct AchievementsCard: View {
    let viewModel: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(BrandSymbolFont.symbol(18))
                    .foregroundStyle(.gsBrandPrimary)
                Text("Achievements")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Spacer()
                Text("\(viewModel.unlockedAchievements.count)/\(Achievement.allCases.count)")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.rowSpacing) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            unlocked: viewModel.isUnlocked(achievement)
                        )
                    }
                }
                .padding(.bottom, AppSpacing.smallSpacing)
            }
            .scrollClipDisabled()
        }
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        VStack(spacing: AppSpacing.smallSpacing) {
            ZStack {
                Circle()
                    .fill(unlocked
                        ? .gsBrandPrimary.opacity(0.15)
                        : .gsSurface)
                    .frame(width: 56, height: 56)
                    .pillShadow()

                Image(systemName: achievement.icon)
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(unlocked ? .gsBrandPrimary : .gsTextSecondary.opacity(0.4))

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(BrandSymbolFont.symbol(13, weight: .regular))
                        .foregroundStyle(.gsTextSecondary.opacity(0.6))
                        .offset(x: 16, y: 16)
                }
            }

            Text(achievement.title)
                .font(BrandFont.semiBold(13))
                .foregroundStyle(unlocked ? .gsTextPrimary : .gsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(width: 68)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(unlocked ? "unlocked" : "locked: \(achievement.requirement)")")
    }
}

// MARK: - Empty Data Placeholder

struct EmptyDataView: View {
    let message: String

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.smallSpacing) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(BrandSymbolFont.symbol(22, weight: .medium))
                .foregroundStyle(EmptyStateChrome.symbolTealGradient)
                .accessibilityHidden(true)
            Text(message)
                .font(BrandFont.regular(15))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
        .padding(.vertical, AppSpacing.smallSpacing)
    }
}
