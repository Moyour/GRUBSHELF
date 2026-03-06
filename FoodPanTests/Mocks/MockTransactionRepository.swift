import Foundation
@testable import FoodPan

final class MockTransactionRepository: TransactionRepository, @unchecked Sendable {
    var transactions: [Transaction] = []
    var shouldThrow = false

    func add(_ transaction: Transaction) async throws -> Transaction {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        transactions.append(transaction)
        return transaction
    }

    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [Transaction] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return transactions.filter {
            $0.householdId == householdId &&
            $0.purchaseDate >= start &&
            $0.purchaseDate < end
        }
    }
}
