import Testing
import Foundation
@testable import GrubShelf

struct FinancialServiceTests {
    private let householdId = UUID()

    private func makeTransaction(
        cost: Int = 1000,
        date: Date = .now,
        householdId: UUID? = nil
    ) -> Transaction {
        Transaction(
            transactionId: UUID(),
            householdId: householdId ?? self.householdId,
            itemId: UUID(),
            quantityPurchased: 1,
            totalCostMinor: cost,
            costPerUnitMinor: cost,
            purchaseDate: date,
            storeName: "TestStore"
        )
    }

    private func makePantryItem(
        state: ItemState,
        cost: Int = 500,
        quantity: Double = 2
    ) -> PantryItem {
        let expiry: Date? = switch state {
        case .expired: Date.now.addingTimeInterval(-86400)
        case .expiringSoon: Date.now.addingTimeInterval(86400)
        default: nil
        }
        return PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: "Test",
            quantity: state == .archived ? 0 : quantity,
            unit: .pcs,
            category: "Test",
            expiryDate: expiry,
            costPerUnitMinor: cost,
            lowStockThreshold: state == .lowStock ? quantity : 0,
            createdBy: UUID(),
            createdAt: .now,
            updatedAt: .now,
            archived: state == .archived
        )
    }

    @Test func monthlySpendSumsTransactions() async throws {
        let txnRepo = MockTransactionRepository()
        let pantryRepo = MockPantryRepository()

        // Add transactions in January 2026
        let jan15 = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        txnRepo.transactions = [
            makeTransaction(cost: 1000, date: jan15),
            makeTransaction(cost: 2500, date: jan15),
        ]

        let service = FinancialService(transactionRepository: txnRepo, pantryRepository: pantryRepo)
        let spend = try await service.monthlySpend(householdId: householdId, month: 1, year: 2026)
        #expect(spend == 3500)
    }

    @Test func monthlySpendZeroForEmptyMonth() async throws {
        let txnRepo = MockTransactionRepository()
        let pantryRepo = MockPantryRepository()
        let service = FinancialService(transactionRepository: txnRepo, pantryRepository: pantryRepo)
        let spend = try await service.monthlySpend(householdId: householdId, month: 6, year: 2026)
        #expect(spend == 0)
    }

    @Test func monthlyWasteCalculatesExpiredItems() async throws {
        let txnRepo = MockTransactionRepository()
        let pantryRepo = MockPantryRepository()
        pantryRepo.items = [
            makePantryItem(state: .expired, cost: 300, quantity: 3), // 3 * 300 = 900
            makePantryItem(state: .expired, cost: 200, quantity: 2), // 2 * 200 = 400
            makePantryItem(state: .active, cost: 500, quantity: 5),  // not expired, excluded
        ]

        let service = FinancialService(transactionRepository: txnRepo, pantryRepository: pantryRepo)
        let waste = try await service.monthlyWaste(householdId: householdId)
        #expect(waste == 1300)
    }

    @Test func monthlyWasteZeroIfNoExpired() async throws {
        let txnRepo = MockTransactionRepository()
        let pantryRepo = MockPantryRepository()
        pantryRepo.items = [makePantryItem(state: .active)]

        let service = FinancialService(transactionRepository: txnRepo, pantryRepository: pantryRepo)
        let waste = try await service.monthlyWaste(householdId: householdId)
        #expect(waste == 0)
    }
}
