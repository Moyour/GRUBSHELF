import Foundation

/// Pure helpers for expense heatmap normalization — testable without UI.
enum ExpenseHeatmapBuilder {
    /// Pairs each calendar day with spend and a 0...1 intensity vs the max day in the range.
    static func normalizedDays(
        calendarDays: [Date],
        spendByStartOfDay: [Date: Int],
        calendar: Calendar = .current
    ) -> [(date: Date, amountMinor: Int, intensity: Double)] {
        let amounts: [Int] = calendarDays.map { day in
            let key = calendar.startOfDay(for: day)
            return spendByStartOfDay[key] ?? 0
        }
        let maxAmount = max(amounts.max() ?? 0, 1)
        return zip(calendarDays, amounts).map { date, amount in
            (date, amount, Double(amount) / Double(maxAmount))
        }
    }

    /// Days to show in the heatmap for weekly (7 days of ISO week) or monthly (every day in month).
    static func daysForBudgetPeriod(
        budgetPeriod: BudgetPeriod,
        reference: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        switch budgetPeriod {
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: reference) else { return [] }
            return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        case .monthly:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: reference)),
                  let range = calendar.range(of: .day, in: .month, for: reference)
            else { return [] }
            return range.compactMap { day in
                calendar.date(byAdding: .day, value: day - 1, to: monthStart)
            }
        }
    }
}
