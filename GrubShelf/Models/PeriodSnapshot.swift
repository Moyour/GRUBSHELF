import Foundation

struct PeriodSnapshot: Codable, Identifiable, Equatable, Sendable {
    let snapshotId: UUID
    let householdId: UUID
    var period: String
    var budgetAmountMinor: Int
    var totalSpentMinor: Int
    var totalWasteMinor: Int
    var wasteItemCount: Int
    var tripCount: Int
    var effectiveValueMinor: Int

    var id: UUID { snapshotId }

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case householdId = "household_id"
        case period
        case budgetAmountMinor = "budget_amount_minor"
        case totalSpentMinor = "total_spent_minor"
        case totalWasteMinor = "total_waste_minor"
        case wasteItemCount = "waste_item_count"
        case tripCount = "trip_count"
        case effectiveValueMinor = "effective_value_minor"
    }
}
