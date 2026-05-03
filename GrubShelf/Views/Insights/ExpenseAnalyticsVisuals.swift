import Charts
import SwiftUI

// MARK: - Period story strip (budget → spend → waste → remainder)

struct ExpensePeriodStoryStrip: View {
    let budgetMinor: Int
    let spentMinor: Int
    let wasteMinor: Int
    let currencyCode: String

    private var remainingMinor: Int { budgetMinor - spentMinor }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            Label("Period flow", systemImage: "arrow.left.and.right")
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextPrimary)

            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let budget = Double(budgetMinor)
                let spendRatio = budget > 0 ? min(Double(spentMinor) / budget, 1.0) : 0
                let remainingRatio = budget > 0 ? max((budget - Double(spentMinor)) / budget, 0) : 0
                let wasteRatio = budget > 0 ? min(Double(wasteMinor) / budget, 1.0) : 0
                let over = spentMinor > budgetMinor

                VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius)
                            .fill(Color.gsSurface)
                            .frame(height: 14)
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius)
                                .fill(over ? Color.gsDanger : Color.gsBrandPrimary)
                                .frame(width: CGFloat(spendRatio) * width, height: 14)
                            if remainingRatio > 0.001, !over {
                                RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius)
                                    .fill(Color.gsBrandPrimary.opacity(0.14))
                                    .frame(width: CGFloat(remainingRatio) * width, height: 14)
                            }
                        }
                    }

                    if wasteMinor > 0 {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: AppSpacing.compactGap)
                                .fill(Color.gsTextSecondary.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: AppSpacing.compactGap)
                                .fill(Color.gsWarning.opacity(0.9))
                                .frame(width: CGFloat(wasteRatio) * width, height: 6)
                        }
                    }

                    HStack {
                        legendDot(over ? Color.gsDanger : Color.gsBrandPrimary)
                        Text("Shopping")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                        Text(spentMinor.currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.semiBold(14))
                            .foregroundStyle(.gsTextPrimary)
                    }
                    if wasteMinor > 0 {
                        HStack {
                            legendDot(Color.gsWarning.opacity(0.9))
                            Text("Waste")
                                .font(BrandFont.regular(13))
                                .foregroundStyle(.gsTextSecondary)
                            Spacer()
                            Text(wasteMinor.currencyFormatted(currencyCode: currencyCode))
                                .font(BrandFont.semiBold(14))
                                .foregroundStyle(.gsTextPrimary)
                        }
                    }
                    HStack {
                        legendDot(Color.gsBrandPrimary.opacity(0.35))
                        Text(remainingMinor >= 0 ? "Remaining" : "Over budget")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                        Text(
                            remainingMinor >= 0
                                ? remainingMinor.currencyFormatted(currencyCode: currencyCode)
                                : abs(remainingMinor).currencyFormatted(currencyCode: currencyCode)
                        )
                        .font(BrandFont.semiBold(14))
                        .foregroundStyle(remainingMinor >= 0 ? Color.gsBrandPrimary : Color.gsDanger)
                    }
                }
            }
            .frame(minHeight: wasteMinor > 0 ? 132 : 112)
        }
    }

    private func legendDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: AppSpacing.denseSpacing, height: AppSpacing.denseSpacing)
    }
}

// MARK: - Spending trends (area + line + waste + budget rule)

struct ExpenseTrendsLegend: View {
    var body: some View {
        HStack(spacing: AppSpacing.sectionSpacing) {
            HStack(spacing: AppSpacing.denseSpacing) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gsBrandPrimary)
                    .frame(width: 14, height: 3)
                Text("Spend")
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
            }
            HStack(spacing: AppSpacing.denseSpacing) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gsWarning.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 14, height: 3)
                Text("Waste")
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
            }
            HStack(spacing: AppSpacing.denseSpacing) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gsTextSecondary.opacity(0.45))
                    .frame(width: 14, height: 1)
                Text("Budget")
                    .font(BrandFont.regular(12))
                    .foregroundStyle(.gsTextSecondary)
            }
        }
        .padding(.top, AppSpacing.compactGap)
    }
}

struct ExpenseSpendingTrendsChart: View {
    let snapshots: [PeriodSnapshot]
    let budgetMinor: Int?
    var currencyCode: String = "GBP"

    var body: some View {
        Chart {
            ForEach(snapshots) { snapshot in
                let spent = Double(snapshot.totalSpentMinor) / 100.0
                AreaMark(
                    x: .value("Period", snapshot.period),
                    y: .value("Spent", spent)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gsBrandPrimary.opacity(0.28), Color.gsBrandPrimary.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            ForEach(snapshots) { snapshot in
                let spent = Double(snapshot.totalSpentMinor) / 100.0
                LineMark(
                    x: .value("Period", snapshot.period),
                    y: .value("Spent", spent)
                )
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.gsBrandPrimary)
                .symbol(.circle)
                .symbolSize(72)
            }
            ForEach(snapshots.filter { $0.totalWasteMinor > 0 }) { snapshot in
                LineMark(
                    x: .value("Period", snapshot.period),
                    y: .value("Waste", Double(snapshot.totalWasteMinor) / 100.0)
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                .foregroundStyle(Color.gsWarning.opacity(0.9))
            }
            if let budgetMinor, budgetMinor > 0 {
                RuleMark(y: .value("Budget", Double(budgetMinor) / 100.0))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .foregroundStyle(Color.gsTextSecondary.opacity(0.55))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Budget")
                            .font(BrandFont.regular(10))
                            .foregroundStyle(.gsTextSecondary)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gsTextSecondary.opacity(0.18))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gsTextSecondary.opacity(0.35))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Int(round(v * 100)).currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.regular(11))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gsTextSecondary.opacity(0.12))
                AxisValueLabel()
            }
        }
        .chartPlotStyle { content in
            content.padding(.trailing, 4)
        }
        .frame(height: 228)
        .accessibilityLabel("Spending trends chart")
    }
}

// MARK: - Daily spend heatmap

struct ExpenseSpendHeatmapCard: View {
    let cells: [(date: Date, amountMinor: Int, intensity: Double)]
    let budgetPeriod: BudgetPeriod
    let currencyCode: String

    private var columns: [GridItem] {
        let n = budgetPeriod == .weekly ? 7 : 7
        return Array(repeating: GridItem(.flexible(), spacing: AppSpacing.compactGap), count: n)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack {
                Label("Daily spend", systemImage: "calendar")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Spacer()
                Text(budgetPeriod == .weekly ? "This week" : "This month")
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
            }

            if cells.isEmpty {
                EmptyDataView(message: "No calendar days in this period")
            } else {
                let maxSpend = cells.map(\.amountMinor).max() ?? 0
                LazyVGrid(columns: columns, spacing: AppSpacing.compactGap) {
                    ForEach(cells.indices, id: \.self) { i in
                        let cell = cells[i]
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gsBrandPrimary.opacity(0.12 + cell.intensity * 0.55))
                                .frame(height: budgetPeriod == .monthly ? 22 : 32)
                                .overlay {
                                    Text(shortDay(cell.date))
                                        .font(BrandFont.regular(9))
                                        .foregroundStyle(
                                            cell.amountMinor > 0
                                                ? Color.gsTextPrimary.opacity(0.9)
                                                : Color.gsTextSecondary.opacity(0.45)
                                        )
                                }
                            if budgetPeriod == .weekly {
                                Text(weekdayLetter(cell.date))
                                    .font(BrandFont.regular(9))
                                    .foregroundStyle(.gsTextSecondary)
                            }
                        }
                        .accessibilityLabel(accessibilityDay(cell))
                    }
                }

                if maxSpend > 0 {
                    HStack(spacing: AppSpacing.smallSpacing) {
                        Text("Less")
                            .font(BrandFont.regular(11))
                            .foregroundStyle(.gsTextSecondary)
                        HStack(spacing: AppSpacing.denseSpacing) {
                            ForEach(0 ..< 5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gsBrandPrimary.opacity(0.12 + Double(i) / 4.0 * 0.55))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        Text("More")
                            .font(BrandFont.regular(11))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    .padding(.top, AppSpacing.compactGap)
                }
            }
        }
    }

    private func shortDay(_ date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return "\(d)"
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        f.locale = .current
        return f.string(from: date)
    }

    private func accessibilityDay(
        _ cell: (date: Date, amountMinor: Int, intensity: Double)
    ) -> String {
        let day = cell.date.formatted(date: .abbreviated, time: .omitted)
        if cell.amountMinor == 0 {
            return "\(day), no spend logged"
        }
        return "\(day), \(cell.amountMinor.currencyFormatted(currencyCode: currencyCode))"
    }
}

// MARK: - Monthly spend (flat bars)

struct ExpenseMonthlySpendChart: View {
    let items: [MonthlySpend]

    var body: some View {
        Chart(Array(items.enumerated()), id: \.offset) { index, item in
            let isLatest = index == items.count - 1
            BarMark(
                x: .value("Month", item.month),
                y: .value("Spend", Double(item.amount) / 100.0)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: isLatest
                        ? [Color.gsBrandPrimary, Color.gsBrandPrimary.opacity(0.72)]
                        : [Color.gsBrandPrimary.opacity(0.42), Color.gsBrandPrimary.opacity(0.2)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(6)
            .annotation(position: .top, alignment: .center, spacing: 4) {
                if isLatest, item.amount > 0 {
                    Text(String(localized: "Latest"))
                        .font(BrandFont.regular(10))
                        .foregroundStyle(.gsTextSecondary)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { AxisMarks(preset: .aligned, values: .automatic) }
        .frame(height: 200)
        .accessibilityLabel("Monthly spending chart")
    }
}

// MARK: - Waste: this month vs last month

struct WasteMonthComparisonChart: View {
    let currentMinor: Int
    let lastMinor: Int
    let currencyCode: String

    private struct BarRow: Identifiable {
        let id: String
        let label: String
        let value: Double
        let color: Color
    }

    var body: some View {
        let rows: [BarRow] = [
            BarRow(
                id: "current",
                label: String(localized: "This month"),
                value: Double(currentMinor) / 100.0,
                color: currentMinor > 0 ? Color.gsWarning.opacity(0.92) : Color.gsBrandPrimary.opacity(0.85)
            ),
            BarRow(
                id: "last",
                label: String(localized: "Last month"),
                value: Double(lastMinor) / 100.0,
                color: Color.gsTextSecondary.opacity(0.38)
            )
        ]

        Chart(rows) { row in
            BarMark(
                x: .value("Period", row.label),
                y: .value("Waste", row.value)
            )
            .foregroundStyle(row.color)
            .cornerRadius(8)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { AxisMarks(preset: .aligned, values: .automatic) }
        .frame(height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "Waste comparison chart: this month \(currentMinor.currencyFormatted(currencyCode: currencyCode)), last month \(lastMinor.currencyFormatted(currencyCode: currencyCode))"
            )
        )
    }
}

// MARK: - Chart data helpers (unit-tested)

enum AnalyticsChartHelpers {
    struct CategorySlice: Identifiable, Equatable {
        let id: String
        let name: String
        let count: Int
    }

    /// Top `maxSlices` categories by item count, plus an "Other" bucket when there are more rows.
    static func categoryPieSlices(from rows: [CategorySpend], maxSlices: Int) -> [CategorySlice] {
        guard maxSlices > 0 else { return [] }
        let sorted = rows.sorted { $0.amount > $1.amount }
        guard !sorted.isEmpty else { return [] }
        let head = Array(sorted.prefix(maxSlices))
        if sorted.count <= maxSlices {
            return head.enumerated().map { pair in
                CategorySlice(
                    id: "\(pair.offset)-\(pair.element.category)",
                    name: pair.element.category,
                    count: pair.element.amount
                )
            }
        }
        let rest = sorted.dropFirst(maxSlices)
        let otherSum = rest.reduce(0) { $0 + $1.amount }
        var out: [CategorySlice] = head.enumerated().map { pair in
            CategorySlice(
                id: "\(pair.offset)-\(pair.element.category)",
                name: pair.element.category,
                count: pair.element.amount
            )
        }
        if otherSum > 0 {
            out.append(CategorySlice(id: "other", name: String(localized: "Other"), count: otherSum))
        }
        return out
    }
}

// MARK: - Category pantry: donut + list

struct CategoryPantryBreakdownVisual: View {
    let rows: [CategorySpend]

    private var slices: [AnalyticsChartHelpers.CategorySlice] {
        AnalyticsChartHelpers.categoryPieSlices(from: rows, maxSlices: 5)
    }

    private let sliceColors: [Color] = [
        .gsBrandPrimary,
        Color.gsBrandPrimary.opacity(0.72),
        .gsWarning,
        Color.gsDanger.opacity(0.78),
        Color.gsTextSecondary.opacity(0.65),
        Color.gsBrandPrimary.opacity(0.45)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            if !slices.isEmpty {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value(String(localized: "Items"), slice.count),
                        innerRadius: .ratio(0.56),
                        angularInset: 1.2
                    )
                    .foregroundStyle(by: .value("Category", slice.name))
                }
                .chartLegend(.hidden)
                .frame(height: 176)
                .chartForegroundStyleScale(
                    domain: slices.map(\.name),
                    range: Array(sliceColors.prefix(slices.count))
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.compactGap) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        let color = sliceColors[index % sliceColors.count]
                        HStack(spacing: AppSpacing.denseSpacing) {
                            Circle()
                                .fill(color)
                                .frame(width: AppSpacing.denseSpacing, height: AppSpacing.denseSpacing)
                            Text(slice.name)
                                .font(BrandFont.regular(12))
                                .foregroundStyle(.gsTextPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(slice.count)")
                                .font(BrandFont.mono(12))
                                .foregroundStyle(.gsTextSecondary)
                        }
                    }
                }
            }

            CategoryCountHorizontalBars(rows: Array(rows.prefix(6)))
        }
    }
}

// MARK: - Horizontal bars — category counts (pantry)

struct CategoryCountHorizontalBars: View {
    let rows: [CategorySpend]

    private var maxCount: Int {
        max(rows.map(\.amount).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            ForEach(rows.prefix(6)) { cat in
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    HStack {
                        Text(cat.category)
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(cat.amount)")
                            .font(BrandFont.mono(14))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                    GeometryReader { g in
                        let w = max(g.size.width, 1)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gsBrandPrimary.opacity(0.15))
                            .frame(width: w, height: 8)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gsBrandPrimary)
                                    .frame(width: CGFloat(cat.amount) / CGFloat(maxCount) * w, height: 8)
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

// MARK: - Horizontal bars — currency by category

struct CategoryCurrencyHorizontalBars: View {
    let rows: [CategorySpendAmount]
    let currencyCode: String

    private var maxMinor: Int {
        max(rows.map(\.amountMinor).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            ForEach(rows) { item in
                VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                    HStack {
                        Text(item.category)
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(item.amountMinor.currencyFormatted(currencyCode: currencyCode))
                            .font(BrandFont.semiBold(14))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                    GeometryReader { g in
                        let w = max(g.size.width, 1)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gsBrandPrimary.opacity(0.12))
                            .frame(width: w, height: 8)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gsBrandPrimary.opacity(0.9))
                                    .frame(
                                        width: CGFloat(item.amountMinor) / CGFloat(maxMinor) * w,
                                        height: 8
                                    )
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}
