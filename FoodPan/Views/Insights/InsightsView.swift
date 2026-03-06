import SwiftUI
import Charts

struct InsightsView: View {
    @State var insightsVM: InsightsViewModel
    @State var financeVM: FinanceViewModel
    @Binding var showSettings: Bool
    @State private var selectedTab: InsightsTab = .budget
    @State private var showBudgetSettings = false
    @State private var showLogPurchaseSheet = false
    @State private var showCustomizeAnalytics = false
    @State private var analyticsRefreshTrigger = 0

    enum InsightsTab: String, CaseIterable {
        case budget = "Budget"
        case analytics = "Analytics"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(InsightsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.smallSpacing)

                switch selectedTab {
                case .budget:
                    budgetTab
                case .analytics:
                    analyticsTab
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Insights")
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
                    HStack(spacing: AppSpacing.cardPadding) {
                        if selectedTab == .analytics {
                            Button {
                                showCustomizeAnalytics = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                        Button {
                            showBudgetSettings = true
                        } label: {
                            Image(systemName: "dollarsign.circle")
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCustomizeAnalytics, onDismiss: {
                analyticsRefreshTrigger += 1
            }) {
                CustomizeAnalyticsSheet()
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
        }
    }

    // MARK: - Budget Tab

    private var budgetTab: some View {
        Group {
            if !financeVM.hasBudget && !financeVM.isLoading {
                budgetEmptyState
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        if !financeVM.unloggedTrips.isEmpty {
                            unloggedTripsBanner
                        }
                        budgetHero
                        budgetProgressBar
                        wasteCallout
                        tripHistoryList
                        trendsChart
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
        }
    }

    private var budgetEmptyState: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            VStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: "sterlingsign.circle")
                    .font(.system(size: AppFont.emptyStateIconSize))
                    .foregroundStyle(Color.primaryGreen.opacity(0.4))

                Text("Set up your budget")
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Configure your budget period and amount to start tracking spending.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)

                Button {
                    showBudgetSettings = true
                } label: {
                    Text("Set Up Budget")
                        .font(AppFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(Color.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .padding(.top, AppSpacing.smallSpacing)

                Button {
                    showLogPurchaseSheet = true
                } label: {
                    Text("Or log a quick purchase")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.primaryGreen)
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.smallSpacing)
            }
            .padding(AppSpacing.cardPadding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .cardShadow()
            .padding(.horizontal, AppSpacing.screenPadding)

            Spacer()
        }
    }

    // MARK: - Budget Hero

    private var budgetHero: some View {
        DashboardCard {
            VStack(spacing: AppSpacing.smallSpacing) {
                Text(financeVM.currentPeriodLabel)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)

                if financeVM.budgetRemainingMinor >= 0 {
                    Text(financeVM.budgetRemainingMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(heroColor)
                    Text("remaining of \(financeVM.budgetAmountMinor.currencyFormatted(currencyCode: financeVM.currencyCode))")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                } else {
                    Text(abs(financeVM.budgetRemainingMinor).currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.errorRed)
                    Text("over budget")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.errorRed)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var heroColor: Color {
        switch financeVM.budgetColor {
        case .green: return Color.successGreen
        case .amber: return Color.warningAmber
        case .red: return Color.errorRed
        }
    }

    // MARK: - Progress Bar

    private var budgetProgressBar: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                HStack {
                    Text("Spent")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                    Text(financeVM.totalSpentMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                }
                ProgressView(value: financeVM.spendProgress)
                    .tint(heroColor)
            }
        }
    }

    // MARK: - Waste Callout

    private var wasteCallout: some View {
        DashboardCard {
            HStack(spacing: AppSpacing.rowSpacing) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.errorRed)

                VStack(alignment: .leading, spacing: 2) {
                    if financeVM.hasWasteCostData {
                        Text("\(financeVM.wasteTotalMinor.currencyFormatted(currencyCode: financeVM.currencyCode)) lost to waste")
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
                    }
                    if financeVM.wasteItemCount > 0 {
                        Text("\(financeVM.wasteItemCount) item\(financeVM.wasteItemCount == 1 ? "" : "s") wasted \(financeVM.currentPeriodLabel.lowercased())")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                    } else {
                        Text("No waste recorded \(financeVM.currentPeriodLabel.lowercased())")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.successGreen)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Trip History

    private var tripHistoryList: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                HStack {
                    Label("Shopping Trips", systemImage: "cart.fill")
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Button {
                        showLogPurchaseSheet = true
                    } label: {
                        Text("Log purchase")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.primaryGreen)
                    }
                    .buttonStyle(.plain)
                }

                if financeVM.trips.isEmpty {
                    VStack(spacing: AppSpacing.rowSpacing) {
                        EmptyDataView(message: "No trips logged \(financeVM.currentPeriodLabel.lowercased())")
                        Button {
                            showLogPurchaseSheet = true
                        } label: {
                            Text("Log a purchase")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.primaryGreen)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(financeVM.trips) { trip in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.date, style: .date)
                                    .font(AppFont.body)
                                    .foregroundStyle(Color.primaryText)
                                Text("\(trip.itemCount) item\(trip.itemCount == 1 ? "" : "s")")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            Spacer()
                            if trip.costLogged, let cost = trip.totalCostMinor {
                                Text(cost.currencyFormatted(currencyCode: financeVM.currencyCode))
                                    .font(AppFont.button)
                                    .foregroundStyle(Color.primaryText)
                            } else {
                                Button {
                                    financeVM.tripToLog = trip
                                } label: {
                                    Text("Add cost")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.warningAmber)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                        if trip.id != financeVM.trips.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trends Chart

    private var trendsChart: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                Label("Spending Trends", systemImage: "chart.bar.fill")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)

                if financeVM.historicalSnapshots.isEmpty {
                    EmptyDataView(message: "Trends will appear after your first complete period")
                } else {
                    Chart(financeVM.historicalSnapshots) { snapshot in
                        BarMark(
                            x: .value("Period", snapshot.period),
                            y: .value("Spent", Double(snapshot.totalSpentMinor) / 100.0)
                        )
                        .foregroundStyle(Color.primaryGreen.gradient)
                        .cornerRadius(4)

                        if snapshot.totalWasteMinor > 0 {
                            BarMark(
                                x: .value("Period", snapshot.period),
                                y: .value("Waste", Double(snapshot.totalWasteMinor) / 100.0)
                            )
                            .foregroundStyle(Color.errorRed.opacity(0.6))
                            .cornerRadius(4)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 180)
                    .accessibilityLabel("Spending trends chart")
                }
            }
        }
    }

    // MARK: - Unlogged Trips Banner

    private var unloggedTripsBanner: some View {
        VStack(spacing: 8) {
            ForEach(financeVM.unloggedTrips) { trip in
                HStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.warningAmber)
                    Text("Trip on \(trip.date.formatted(date: .abbreviated, time: .omitted)) — cost not logged.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Button("Add") {
                        financeVM.tripToLog = trip
                    }
                    .font(AppFont.caption)
                    .foregroundStyle(Color.primaryGreen)
                }
                .padding(AppSpacing.cardPadding)
                .background(Color.warningAmber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    // MARK: - Analytics Tab

    private var analyticsTab: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                ForEach(AnalyticsPreferences.enabledCardsSorted, id: \.rawValue) { card in
                    analyticsCardView(for: card)
                }
            }
            .padding(AppSpacing.screenPadding)
            .id(analyticsRefreshTrigger)
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
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    if insightsVM.monthlySpendData.isEmpty || insightsVM.monthlySpendData.allSatisfy({ $0.amount == 0 }) {
                        EmptyDataView(message: "Start logging purchases to see spending trends")
                    } else {
                        Chart(insightsVM.monthlySpendData) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Spend", Double(item.amount) / 100.0))
                                .foregroundStyle(Color.primaryGreen.gradient)
                                .cornerRadius(4)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 180)
                        .accessibilityLabel("Monthly spending chart")
                    }
                }
            }
        case .categoryBreakdown:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Items by Category", systemImage: "tag.fill")
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    if insightsVM.categoryBreakdown.isEmpty {
                        EmptyDataView(message: "Add pantry items to see category breakdown")
                    } else {
                        ForEach(insightsVM.categoryBreakdown.prefix(6)) { cat in
                            HStack {
                                Text(cat.category).font(AppFont.body).foregroundStyle(Color.primaryText)
                                Spacer()
                                Text("\(cat.amount)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primaryGreen)
                            }
                            if cat.id != insightsVM.categoryBreakdown.prefix(6).last?.id { Divider() }
                        }
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
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    HStack(spacing: AppSpacing.sectionSpacing) {
                        EfficiencyStat(value: "\(insightsVM.shoppingCompleted)", label: "Completed", color: Color.successGreen)
                        EfficiencyStat(value: "\(insightsVM.shoppingTotal - insightsVM.shoppingCompleted)", label: "Pending", color: Color.accentBlue)
                        EfficiencyStat(value: "\(Int(insightsVM.shoppingCompletionRate))%", label: "Rate",
                            color: insightsVM.shoppingCompletionRate >= 80 ? Color.successGreen : Color.warningAmber)
                    }
                    if insightsVM.shoppingTotal > 0 {
                        ProgressView(value: insightsVM.shoppingCompletionRate, total: 100)
                            .tint(insightsVM.shoppingCompletionRate >= 80 ? Color.successGreen : Color.primaryGreen)
                    }
                }
            }
        case .lowStockCount:
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    Label("Low Stock", systemImage: "cart.badge.plus")
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    Text("\(insightsVM.lowStockCount) item\(insightsVM.lowStockCount == 1 ? "" : "s") running low")
                        .font(AppFont.body)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        case .expiringSoon:
            if !insightsVM.expiringItems.isEmpty {
                DashboardCard {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
                        ForEach(insightsVM.expiringItems.prefix(5)) { item in
                            HStack {
                                Text(item.name).font(AppFont.body).foregroundStyle(Color.primaryText)
                                Spacer()
                                if let expiry = item.expiryDate {
                                    Text(expiry, style: .date)
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.secondaryText)
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
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    Text(insightsVM.totalPantryValueMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryGreen)
                }
            }
        case .averageTripCost:
            if insightsVM.averageTripCostMinor > 0 {
                DashboardCard {
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        Label("Average Trip Cost", systemImage: "cart.fill")
                            .font(AppFont.button)
                            .foregroundStyle(Color.primaryText)
                        Text(insightsVM.averageTripCostMinor.currencyFormatted(currencyCode: financeVM.currencyCode))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primaryGreen)
                    }
                }
            }
        case .achievements:
            AchievementsCard(viewModel: insightsVM)
        }
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
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                ForEach(items) { item in
                    HStack {
                        Text(item.name).font(AppFont.body).foregroundStyle(Color.primaryText)
                        Spacer()
                        Text("\(item.count)x")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.secondaryText)
                            .padding(.horizontal, AppSpacing.smallSpacing)
                            .padding(.vertical, AppSpacing.smallSpacing / 2)
                            .background(Color.primaryGreen.opacity(0.12))
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
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                ForEach(items) { item in
                    HStack {
                        Text(item.name).font(AppFont.body).foregroundStyle(Color.primaryText)
                        Spacer()
                        Text(item.amountMinor.currencyFormatted(currencyCode: currencyCode))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primaryGreen)
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
                Label("Most Spent by Category", systemImage: "chart.pie.fill")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                ForEach(items) { item in
                    HStack {
                        Text(item.category).font(AppFont.body).foregroundStyle(Color.primaryText)
                        Spacer()
                        Text(item.amountMinor.currencyFormatted(currencyCode: currencyCode))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primaryGreen)
                    }
                }
            }
        }
    }
}

// MARK: - Smart Tips Section

struct SmartTipsSection: View {
    let tips: [SmartTip]

    var body: some View {
        VStack(spacing: AppSpacing.smallSpacing) {
            ForEach(tips) { tip in
                HStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: tip.icon)
                        .font(.title3)
                        .foregroundStyle(tipColor(tip.color))
                        .frame(width: 28)

                    Text(tip.message)
                        .font(AppFont.body)
                        .foregroundStyle(Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(AppSpacing.cardPadding)
                .background(tipColor(tip.color).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    private func tipColor(_ color: SmartTip.TipColor) -> Color {
        switch color {
        case .warning: return Color.warningAmber
        case .success: return Color.successGreen
        case .info: return Color.accentBlue
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
                        .font(AppFont.button)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    directionBadge
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sectionSpacing) {
                    VStack(alignment: .leading, spacing: AppSpacing.smallSpacing / 2) {
                        Text("This Month")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                        Text(currentWaste.currencyFormatted(currencyCode: currencyCode))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(currentWaste > 0 ? Color.errorRed : Color.successGreen)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.smallSpacing / 2) {
                        Text("Last Month")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                        Text(lastMonthWaste.currencyFormatted(currencyCode: currencyCode))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                if expiredCount > 0 {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.errorRed)
                            .font(.caption)
                        Text("\(expiredCount) item\(expiredCount == 1 ? "" : "s") expired this month")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                } else {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.successGreen)
                            .font(.caption)
                        Text("No waste — great job!")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.successGreen)
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
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.successGreen)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.smallSpacing / 2)
                .background(Color.successGreen.opacity(0.12))
                .clipShape(Capsule())
        case .up:
            Label("Increasing", systemImage: "arrow.up.right")
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.errorRed)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.smallSpacing / 2)
                .background(Color.errorRed.opacity(0.12))
                .clipShape(Capsule())
        case .flat:
            Label("Stable", systemImage: "arrow.right")
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.secondaryText)
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.smallSpacing / 2)
                .background(Color.cardBackground)
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
        VStack(spacing: AppSpacing.smallSpacing / 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(AppFont.badgeLabel)
                .foregroundStyle(Color.secondaryText)
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
                    .foregroundStyle(Color.warningAmber)
                Text("Achievements")
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(viewModel.unlockedAchievements.count)/\(Achievement.allCases.count)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.rowSpacing) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            unlocked: viewModel.isUnlocked(achievement)
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
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
                        ? Color.primaryGreen.opacity(0.15)
                        : Color.cardBackground)
                    .frame(width: 56, height: 56)
                    .pillShadow()

                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(unlocked ? Color.primaryGreen : Color.secondaryText.opacity(0.4))

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText.opacity(0.6))
                        .offset(x: 16, y: 16)
                }
            }

            Text(achievement.title)
                .font(AppFont.tinyLabel)
                .foregroundStyle(unlocked ? Color.primaryText : Color.secondaryText)
                .lineLimit(1)
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
        HStack(spacing: AppSpacing.smallSpacing) {
            Image(systemName: "tray")
                .foregroundStyle(Color.secondaryText)
            Text(message)
                .font(AppFont.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, AppSpacing.sectionSpacing)
    }
}
