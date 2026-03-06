import Foundation

protocol PeriodSnapshotRepository: Sendable {
    func upsert(_ snapshot: PeriodSnapshot) async throws -> PeriodSnapshot
    func fetchRecent(householdId: UUID, limit: Int) async throws -> [PeriodSnapshot]
    func fetch(householdId: UUID, period: String) async throws -> PeriodSnapshot?
}
