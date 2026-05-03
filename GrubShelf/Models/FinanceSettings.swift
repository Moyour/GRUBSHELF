import Foundation

enum BudgetPeriod: String, Codable, Sendable, CaseIterable {
    case weekly
    case monthly
}

struct FinanceSettings: Codable, Equatable, Sendable {
    let userId: UUID
    var budgetPeriod: BudgetPeriod
    var budgetAmountMinor: Int
    var periodStartDay: Int
    var currency: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case budgetPeriod = "budget_period"
        case budgetAmountMinor = "budget_amount_minor"
        case periodStartDay = "period_start_day"
        case currency
    }
}
