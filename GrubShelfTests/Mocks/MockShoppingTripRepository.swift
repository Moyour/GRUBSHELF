import Foundation
@testable import GrubShelf

final class MockShoppingTripRepository: ShoppingTripRepository, @unchecked Sendable {
    var tripsByDateRange: [ShoppingTrip] = []
    var recentTrips: [ShoppingTrip] = []
    var unloggedTrips: [ShoppingTrip] = []
    var addedTrips: [ShoppingTrip] = []
    var shouldThrow = false

    func add(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        addedTrips.append(trip)
        return trip
    }

    func update(_ trip: ShoppingTrip) async throws -> ShoppingTrip {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return trip
    }

    func fetchByPeriod(householdId: UUID, period: String) async throws -> [ShoppingTrip] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return tripsByDateRange.filter { $0.householdId == householdId && $0.period == period }
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [ShoppingTrip] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return tripsByDateRange.filter { trip in
            trip.householdId == householdId && trip.date >= start && trip.date <= end
        }
    }

    func fetchRecent(householdId: UUID, limit: Int) async throws -> [ShoppingTrip] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return Array(recentTrips.filter { $0.householdId == householdId }.prefix(limit))
    }

    func fetchUnlogged(householdId: UUID) async throws -> [ShoppingTrip] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return unloggedTrips.filter { $0.householdId == householdId }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingTrip]> {
        AsyncStream { $0.finish() }
    }
}
