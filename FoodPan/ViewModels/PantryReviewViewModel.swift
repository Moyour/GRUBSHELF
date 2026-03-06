import Foundation
import Observation

@MainActor
@Observable
final class PantryReviewViewModel {
    var staleItems: [PantryItem] = []
    var showRemovalPrompt = false
    var itemToRemove: PantryItem?

    private let repository: PantryRepository
    private let householdId: UUID

    var groupedByCategory: [(category: String, items: [PantryItem])] {
        let grouped = Dictionary(grouping: staleItems) { $0.category }
        return grouped.map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    init(repository: PantryRepository, householdId: UUID, staleItems: [PantryItem]) {
        self.repository = repository
        self.householdId = householdId
        self.staleItems = staleItems
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

    func markFinished(_ item: PantryItem) {
        itemToRemove = item
        showRemovalPrompt = true
    }

    func confirmUsed() async {
        guard let item = itemToRemove else { return }
        do {
            try await repository.delete(itemId: item.itemId)
            staleItems.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("\(item.name) removed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to delete \(item.name)", style: .error)
        }
        itemToRemove = nil
    }

    func confirmWasted() async {
        guard let item = itemToRemove else { return }
        do {
            try await repository.delete(itemId: item.itemId)
            staleItems.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("\(item.name) removed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to delete \(item.name)", style: .error)
        }
        itemToRemove = nil
    }
}
