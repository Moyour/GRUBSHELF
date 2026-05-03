import Foundation

protocol TransactionRepository: Sendable {
    func add(_ transaction: Transaction) async throws -> Transaction
    func fetchByDateRange(householdId: UUID, start: Date, end: Date) async throws -> [Transaction]
}
