import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class TransferViewModel {
    var transferItems: [TransferItem] = []
    var isLoading = false
    var errorMessage: String?
    var tripTotalCost: String = ""

    var canTransfer: Bool {
        guard let amount = Double(tripTotalCost.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            return false
        }
        return true
    }

    private let pantryRepository: PantryRepository
    private let transactionRepository: TransactionRepository
    private let shoppingRepository: ShoppingRepository
    private let shoppingTripRepository: ShoppingTripRepository
    private let shoppingListRepository: ShoppingListRepository
    private let financeSettingsRepository: FinanceSettingsRepository
    private let householdId: UUID
    private let userId: UUID
    private let listId: UUID?
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    struct TransferItem: Identifiable {
        let id: UUID
        let shoppingItem: ShoppingItem
        var quantity: String
        var hasExpiry: Bool = false
        var expiryDate: Date = Date.now.addingTimeInterval(7 * 24 * 60 * 60)
        var totalCost: String = ""
        var storeName: String = ""
    }

    init(
        completedItems: [ShoppingItem],
        pantryRepository: PantryRepository,
        transactionRepository: TransactionRepository,
        shoppingRepository: ShoppingRepository,
        shoppingTripRepository: ShoppingTripRepository = SupabaseShoppingTripRepository(),
        shoppingListRepository: ShoppingListRepository = SupabaseShoppingListRepository(),
        financeSettingsRepository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository(),
        householdId: UUID,
        userId: UUID,
        listId: UUID? = nil
    ) {
        self.pantryRepository = pantryRepository
        self.transactionRepository = transactionRepository
        self.shoppingRepository = shoppingRepository
        self.shoppingTripRepository = shoppingTripRepository
        self.shoppingListRepository = shoppingListRepository
        self.financeSettingsRepository = financeSettingsRepository
        self.householdId = householdId
        self.userId = userId
        self.listId = listId

        self.transferItems = completedItems.map {
            TransferItem(
                id: $0.itemId,
                shoppingItem: $0,
                quantity: String($0.quantity)
            )
        }
    }

    func executeTransfer() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            for item in transferItems {
                let qty = Double(item.quantity) ?? item.shoppingItem.quantity
                let costMinor = Int((Double(item.totalCost) ?? 0) * 100)
                let costPerUnit = qty > 0 ? bankersRound(Double(costMinor) / qty) : 0

                let resolvedCategory = item.shoppingItem.category ?? "Other"
                let pantryItem = PantryItem(
                    itemId: UUID(),
                    householdId: householdId,
                    name: item.shoppingItem.name,
                    quantity: qty,
                    unit: item.shoppingItem.unit ?? .pcs,
                    category: resolvedCategory,
                    expiryDate: item.hasExpiry ? item.expiryDate : nil,
                    costPerUnitMinor: costPerUnit,
                    lowStockThreshold: 1,
                    createdBy: userId,
                    createdAt: .now,
                    updatedAt: .now,
                    archived: false,
                    lastQuantityUpdateDate: .now,
                    expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: resolvedCategory)
                )
                _ = try await pantryRepository.add(pantryItem)

                if costMinor > 0 {
                    let transaction = Transaction(
                        transactionId: UUID(),
                        householdId: householdId,
                        itemId: pantryItem.itemId,
                        quantityPurchased: qty,
                        totalCostMinor: costMinor,
                        costPerUnitMinor: costPerUnit,
                        purchaseDate: .now,
                        storeName: item.storeName.isEmpty ? nil : item.storeName
                    )
                    _ = try await transactionRepository.add(transaction)
                }
            }

            haptic.impactOccurred()

            // Mark each shopping item as transferred
            await markItemsTransferred()

            // Mark the list as transferred if no untransferred completed items remain
            await markListTransferredIfComplete()

            // Log the shopping trip
            await logShoppingTrip()

            let count = transferItems.count
            ToastManager.shared.show("\(count) item\(count == 1 ? "" : "s") moved to pantry", style: .success)

            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show("Transfer failed", style: .error)
            isLoading = false
            return false
        }
    }

    private func markItemsTransferred() async {
        for item in transferItems {
            do {
                _ = try await shoppingRepository.markTransferred(itemId: item.shoppingItem.itemId)
            } catch {
                // Best-effort — pantry items already created, don't block transfer
            }
        }
    }

    private func markListTransferredIfComplete() async {
        guard let listId else { return }
        do {
            // Check if all completed items in the list are now transferred
            let allItems = try await shoppingRepository.fetchByList(listId: listId)
            let hasUntransferred = allItems.contains { $0.completed && !$0.transferred }
            if !hasUntransferred {
                let lists = try await shoppingListRepository.fetchAll(householdId: householdId)
                if var list = lists.first(where: { $0.listId == listId }) {
                    list.transferred = true
                    _ = try await shoppingListRepository.update(list)
                }
            }
        } catch {
            // Best-effort — list transfer flag is cosmetic, don't block
        }
    }

    private func logShoppingTrip() async {
        let costMinor: Int? = if let amount = Double(tripTotalCost.trimmingCharacters(in: .whitespaces)), amount > 0 {
            Int(amount * 100)
        } else {
            nil
        }
        let costLogged = costMinor != nil

        let period = await computePeriodString()

        let trip = ShoppingTrip(
            tripId: UUID(),
            householdId: householdId,
            shoppingListId: listId,
            date: .now,
            totalCostMinor: costMinor,
            itemCount: transferItems.count,
            period: period,
            costLogged: costLogged
        )

        do {
            _ = try await shoppingTripRepository.add(trip)
        } catch {
            // Trip logging is best-effort — pantry transfer already succeeded
        }
    }

    private func computePeriodString() async -> String {
        let calendar = Calendar.current
        let now = Date.now

        // Try to use user's finance settings for period calculation
        if let settings = try? await financeSettingsRepository.fetch(userId: userId) {
            switch settings.budgetPeriod {
            case .weekly:
                let year = calendar.component(.yearForWeekOfYear, from: now)
                let week = calendar.component(.weekOfYear, from: now)
                return String(format: "%d-W%02d", year, week)
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: now)
                return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
            }
        }

        // Fallback to monthly
        let comps = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
    }

    private func bankersRound(_ value: Double) -> Int {
        let decimal = NSDecimalNumber(value: value)
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        return decimal.rounding(accordingToBehavior: handler).intValue
    }
}
