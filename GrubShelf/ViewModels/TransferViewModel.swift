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
    /// True when `tripTotalCost` was prefilled from a previous logged shop.
    var didPrefillTripTotal = false

    var canTransfer: Bool {
        let trimmed = tripTotalCost.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        guard let amount = Double(trimmed), amount > 0 else { return false }
        return true
    }

    private let pantryRepository: PantryRepository
    private let transactionRepository: TransactionRepository
    private let shoppingRepository: ShoppingRepository
    private let shoppingTripRepository: ShoppingTripRepository
    private let shoppingListRepository: ShoppingListRepository
    private let financeSettingsRepository: FinanceSettingsRepository
    private let wasteEventRepository: WasteEventRepository
    private let householdId: UUID
    private let userId: UUID
    private let listId: UUID?
    private let auditEntries: [AuditEntry]
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
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        householdId: UUID,
        userId: UUID,
        listId: UUID? = nil,
        auditEntries: [AuditEntry] = []
    ) {
        self.pantryRepository = pantryRepository
        self.transactionRepository = transactionRepository
        self.shoppingRepository = shoppingRepository
        self.shoppingTripRepository = shoppingTripRepository
        self.shoppingListRepository = shoppingListRepository
        self.financeSettingsRepository = financeSettingsRepository
        self.wasteEventRepository = wasteEventRepository
        self.householdId = householdId
        self.userId = userId
        self.listId = listId
        self.auditEntries = auditEntries

        self.transferItems = completedItems.map {
            TransferItem(
                id: $0.itemId,
                shoppingItem: $0,
                quantity: String($0.quantity)
            )
        }
    }

    /// Prefills trip total from the most recent shop with a logged cost (last 30 days).
    func loadSuggestedTripTotal() async {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -30, to: .now) else { return }
        guard let trips = try? await shoppingTripRepository.fetchByDateRange(
            householdId: householdId,
            start: start,
            end: .now
        ) else { return }

        guard let last = trips.first(where: { trip in
            trip.costLogged && (trip.totalCostMinor ?? 0) > 0
        }), let minor = last.totalCostMinor else {
            return
        }

        tripTotalCost = Self.formatMajorAmount(fromMinor: minor)
        didPrefillTripTotal = true
    }

    func executeTransfer() async -> Bool {
        isLoading = true
        errorMessage = nil

        let total = transferItems.count
        var completed = 0
        var failedItems: [String] = []

        for item in transferItems {
            do {
                let qty = Double(item.quantity) ?? item.shoppingItem.quantity
                let costMinor = Int((Double(item.totalCost) ?? 0) * 100)
                let costPerUnit = qty > 0 ? bankersRound(Double(costMinor) / qty) : 0
                let resolvedCategory = item.shoppingItem.category ?? "Other"

                let pantryItemId = try await applyAuditResolution(
                    for: item,
                    qty: qty,
                    category: resolvedCategory,
                    costPerUnit: costPerUnit
                )

                if costMinor > 0 {
                    let transaction = Transaction(
                        transactionId: UUID(),
                        householdId: householdId,
                        itemId: pantryItemId,
                        quantityPurchased: qty,
                        totalCostMinor: costMinor,
                        costPerUnitMinor: costPerUnit,
                        purchaseDate: .now,
                        storeName: item.storeName.isEmpty ? nil : item.storeName
                    )
                    _ = try await transactionRepository.add(transaction)
                }
                completed += 1
            } catch {
                failedItems.append(item.shoppingItem.name)
            }
        }

        // Show results
        if failedItems.isEmpty {
            haptic.impactOccurred()
            await markItemsTransferred()
            await markListTransferredIfComplete()
            await logShoppingTrip()

            EngagementStore.shared.recordShoppingAction()
            BetaTelemetryService.shared.logFirstTransfer()
            ToastManager.shared.show(
                "\(total) item\(total == 1 ? "" : "s") moved to pantry",
                style: .success
            )
            isLoading = false
            return true
        } else {
            let successCount = completed

            // Create detailed error message with item names
            let itemsList = failedItems.prefix(3).joined(separator: ", ")
            let moreText = failedItems.count > 3 ? " and \(failedItems.count - 3) more" : ""

            let message = if successCount > 0 {
                "\(successCount) of \(total) transferred. Couldn't move: \(itemsList)\(moreText)"
            } else {
                "Couldn't move: \(itemsList)\(moreText)"
            }

            errorMessage = message
            ToastManager.shared.show(message, style: .error)
            isLoading = false
            return false
        }
    }

    // MARK: - Audit Resolution

    private func applyAuditResolution(
        for item: TransferItem,
        qty: Double,
        category: String,
        costPerUnit: Int
    ) async throws -> UUID {
        let auditEntry = auditEntries.first { $0.id == item.shoppingItem.itemId }

        guard let auditEntry, let matchedPantry = auditEntry.matchedPantryItem else {
            let newItem = makePantryItem(from: item, qty: qty, category: category, costPerUnit: costPerUnit)
            _ = try await pantryRepository.add(newItem)
            return newItem.itemId
        }

        switch auditEntry.resolution {
        case .usedAll:
            try await pantryRepository.delete(itemId: matchedPantry.itemId)
            let newItem = makePantryItem(from: item, qty: qty, category: category, costPerUnit: costPerUnit)
            _ = try await pantryRepository.add(newItem)
            return newItem.itemId

        case .stillHaveSome:
            var updated = matchedPantry
            updated.quantity += qty
            updated.lastQuantityUpdateDate = .now
            updated.updatedAt = .now
            if costPerUnit > 0 { updated.costPerUnitMinor = costPerUnit }
            if item.hasExpiry { updated.expiryDate = item.expiryDate }
            _ = try await pantryRepository.update(updated)
            return matchedPantry.itemId

        case .wentBad:
            await logWasteEvent(for: matchedPantry)
            try await pantryRepository.delete(itemId: matchedPantry.itemId)
            let newItem = makePantryItem(from: item, qty: qty, category: category, costPerUnit: costPerUnit)
            _ = try await pantryRepository.add(newItem)
            return newItem.itemId
        }
    }

    // MARK: - Helpers

    private func makePantryItem(from item: TransferItem, qty: Double, category: String, costPerUnit: Int) -> PantryItem {
        PantryItem(
            itemId: UUID(),
            householdId: householdId,
            name: item.shoppingItem.name,
            quantity: qty,
            unit: item.shoppingItem.unit ?? .pcs,
            category: category,
            storageLocation: .shelf,
            expiryDate: item.hasExpiry ? item.expiryDate : nil,
            costPerUnitMinor: costPerUnit,
            lowStockThreshold: 1,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            archived: false,
            lastQuantityUpdateDate: .now,
            expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: category)
        )
    }

    private func logWasteEvent(for pantryItem: PantryItem) async {
        let period = await computePeriodString()
        let estimatedCost: Int? = if let cost = pantryItem.costPerUnitMinor {
            Int(Double(cost) * pantryItem.quantity)
        } else {
            nil
        }

        let waste = WasteEvent(
            eventId: UUID(),
            householdId: householdId,
            pantryItemId: pantryItem.itemId,
            itemName: pantryItem.name,
            date: .now,
            estimatedCostMinor: estimatedCost,
            period: period,
            source: "shopping_audit"
        )
        _ = try? await wasteEventRepository.add(waste)
    }

    private func markItemsTransferred() async {
        for item in transferItems {
            do {
                _ = try await shoppingRepository.markTransferred(itemId: item.shoppingItem.itemId)
            } catch {
                // Best-effort
            }
        }
    }

    private func markListTransferredIfComplete() async {
        guard let listId else { return }
        do {
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
            // Best-effort
        }
    }

    private func logShoppingTrip() async {
        let trimmed = tripTotalCost.trimmingCharacters(in: .whitespaces)
        guard let amount = Double(trimmed), amount > 0 else { return }

        let costMinor = Int(amount * 100)
        let period = await computePeriodString()

        let trip = ShoppingTrip(
            tripId: UUID(),
            householdId: householdId,
            shoppingListId: listId,
            date: .now,
            totalCostMinor: costMinor,
            itemCount: transferItems.count,
            period: period,
            costLogged: true
        )

        _ = try? await shoppingTripRepository.add(trip)
    }

    static func formatMajorAmount(fromMinor minor: Int) -> String {
        let major = Double(minor) / 100.0
        if major.rounded(.towardZero) == major {
            return String(format: "%.0f", major)
        }
        return String(format: "%.2f", major)
    }

    private func computePeriodString() async -> String {
        let calendar = Calendar.current
        let now = Date.now

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
