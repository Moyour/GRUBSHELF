import Foundation
import Observation

@MainActor
@Observable
final class PantryReviewViewModel {
    var staleItems: [PantryItem] = []
    var showRemovalPrompt = false
    var showWasteCostPrompt = false
    var itemToRemove: PantryItem?
    var wasteCostText = ""
    private var pendingWasteSource: WasteEventSource?

    private let repository: PantryRepository
    private let householdId: UUID
    private let userId: UUID
    private let wasteEventRepository: WasteEventRepository
    private let financeSettingsRepository: FinanceSettingsRepository

    var groupedByCategory: [(category: String, items: [PantryItem])] {
        let grouped = Dictionary(grouping: staleItems) { $0.category }
        return grouped.map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    init(
        repository: PantryRepository,
        householdId: UUID,
        userId: UUID,
        staleItems: [PantryItem],
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        financeSettingsRepository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository()
    ) {
        self.repository = repository
        self.householdId = householdId
        self.userId = userId
        self.staleItems = staleItems
        self.wasteEventRepository = wasteEventRepository
        self.financeSettingsRepository = financeSettingsRepository
    }

    func confirmAllStillHave() async {
        let snapshot = staleItems
        for item in snapshot {
            await markStillHaveIt(item)
        }
    }

    func markStillHaveIt(_ item: PantryItem) async {
        guard let index = staleItems.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = staleItems[index]
        updated.lastQuantityUpdateDate = .now
        updated.updatedAt = .now
        do {
            _ = try await repository.update(updated)
            staleItems.remove(at: index)
            ToastManager.shared.show("\(updated.name) confirmed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to update \(item.name)", style: .error)
        }
    }

    func markFinished(_ item: PantryItem) async {
        itemToRemove = item
        await confirmUsed()
    }

    func showRemovalOptions(for item: PantryItem) {
        itemToRemove = item
        showRemovalPrompt = true
    }

    func confirmUsed() async {
        guard let item = itemToRemove else { return }
        do {
            try await repository.delete(itemId: item.itemId)
            staleItems.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("Used \(item.name)", style: .success)
        } catch {
            ToastManager.shared.show("Failed to delete \(item.name)", style: .error)
        }
        clearRemovalFlowState()
    }

    func confirmRemoveFromList() async {
        guard let item = itemToRemove else { return }
        do {
            try await repository.delete(itemId: item.itemId)
            staleItems.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("\(item.name) removed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to delete \(item.name)", style: .error)
        }
        clearRemovalFlowState()
    }

    func beginExpiredRemoval(for item: PantryItem? = nil) {
        if let item { itemToRemove = item }
        pendingWasteSource = .expired
        showWasteCostPrompt = true
    }

    func beginWasteRemoval(for item: PantryItem? = nil) {
        if let item { itemToRemove = item }
        pendingWasteSource = .waste
        showWasteCostPrompt = true
    }

    func saveWasteEvent(skipCost: Bool = false) async {
        guard let item = itemToRemove, let pendingWasteSource else { return }

        let costMinor: Int? = if skipCost {
            nil
        } else if let amount = Double(wasteCostText), amount > 0 {
            Int(amount * 100)
        } else {
            nil
        }

        let event = WasteEvent(
            eventId: UUID(),
            householdId: householdId,
            pantryItemId: item.itemId,
            itemName: item.name,
            date: .now,
            estimatedCostMinor: costMinor,
            period: await computePeriodString(),
            source: pendingWasteSource.rawValue
        )
        do {
            _ = try await wasteEventRepository.add(event)
            ToastManager.shared.show("Waste tracked", style: .success)
        } catch {
            ToastManager.shared.show("Couldn't save that waste note", style: .error)
        }

        await confirmRemoveFromList()
    }

    func cancelRemovalFlow() {
        clearRemovalFlowState()
    }

    private func clearRemovalFlowState() {
        itemToRemove = nil
        wasteCostText = ""
        pendingWasteSource = nil
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
}
