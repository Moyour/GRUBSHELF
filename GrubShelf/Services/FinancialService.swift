import Foundation

final class FinancialService {
    private let transactionRepository: TransactionRepository
    private let pantryRepository: PantryRepository

    init(
        transactionRepository: TransactionRepository = SupabaseTransactionRepository(),
        pantryRepository: PantryRepository = SupabasePantryRepository()
    ) {
        self.transactionRepository = transactionRepository
        self.pantryRepository = pantryRepository
    }

    func monthlySpend(householdId: UUID, month: Int, year: Int) async throws -> Int {
        let (start, end) = dateRange(month: month, year: year)
        let transactions = try await transactionRepository.fetchByDateRange(
            householdId: householdId, start: start, end: end
        )
        return transactions.reduce(0) { $0 + $1.totalCostMinor }
    }

    func monthlyWaste(householdId: UUID) async throws -> Int {
        let items = try await pantryRepository.fetchAll(householdId: householdId)
        return items
            .filter { $0.state == .expired }
            .reduce(0) { total, item in
                total + Int(item.quantity * Double(item.costPerUnitMinor ?? 0))
            }
    }

    func monthlySpendBatch(householdId: UUID, months: Int = 6) async throws -> [MonthlySpend] {
        let calendar = Calendar.current
        let now = Date.now
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        guard let rangeStart = calendar.date(byAdding: .month, value: -(months - 1), to: now),
              let firstOfStartMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: rangeStart)),
              let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endBound = calendar.date(byAdding: .month, value: 1, to: currentMonth)
        else { return [] }

        let transactions = try await transactionRepository.fetchByDateRange(
            householdId: householdId, start: firstOfStartMonth, end: endBound
        )

        var buckets: [String: Int] = [:]
        for t in transactions {
            let comps = calendar.dateComponents([.year, .month], from: t.purchaseDate)
            guard let year = comps.year, let month = comps.month else { continue }
            let key = "\(year)-\(month)"
            buckets[key, default: 0] += t.totalCostMinor
        }

        var result: [MonthlySpend] = []
        for offset in (0..<months).reversed() {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else { continue }
            let key = "\(year)-\(month)"
            result.append(MonthlySpend(month: formatter.string(from: date), amount: buckets[key] ?? 0))
        }
        return result
    }

    private func dateRange(month: Int, year: Int) -> (start: Date, end: Date) {
        var start = DateComponents()
        start.year = year
        start.month = month
        start.day = 1

        var end = DateComponents()
        end.year = month == 12 ? year + 1 : year
        end.month = month == 12 ? 1 : month + 1
        end.day = 1

        let calendar = Calendar.current
        return (
            calendar.date(from: start) ?? .now,
            calendar.date(from: end) ?? .now
        )
    }
}
