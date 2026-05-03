import Foundation
@testable import GrubShelf

final class MockWasteEventRepository: WasteEventRepository, @unchecked Sendable {
    var events: [WasteEvent] = []
    var shouldThrow = false

    func add(_ event: WasteEvent) async throws -> WasteEvent {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        events.append(event)
        return event
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [WasteEvent] {
        events.filter { $0.householdId == householdId && $0.period == period }
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [WasteEvent] {
        events.filter { event in
            event.householdId == householdId && event.date >= start && event.date <= end
        }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[WasteEvent]> {
        AsyncStream { continuation in
            continuation.yield(events.filter { $0.householdId == householdId })
            continuation.finish()
        }
    }
}
