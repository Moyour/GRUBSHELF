import Foundation

protocol WasteEventRepository: Sendable {
    func add(_ event: WasteEvent) async throws -> WasteEvent
    func fetchByPeriod(householdId: UUID, period: String) async throws -> [WasteEvent]
    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [WasteEvent]
    func observeChanges(householdId: UUID) -> AsyncStream<[WasteEvent]>
}
