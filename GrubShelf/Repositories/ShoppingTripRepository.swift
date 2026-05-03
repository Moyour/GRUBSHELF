import Foundation

protocol ShoppingTripRepository: Sendable {
    func add(_ trip: ShoppingTrip) async throws -> ShoppingTrip
    func update(_ trip: ShoppingTrip) async throws -> ShoppingTrip
    func fetchByPeriod(householdId: UUID, period: String) async throws -> [ShoppingTrip]
    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [ShoppingTrip]
    func fetchUnlogged(householdId: UUID) async throws -> [ShoppingTrip]
    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingTrip]>
}
