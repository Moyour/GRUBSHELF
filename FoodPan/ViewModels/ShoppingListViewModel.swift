import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ShoppingListViewModel {
    var items: [ShoppingItem] = []
    var newItemName: String = ""
    var showTransferSheet = false
    var showCatalogSearch = false
    var listTransferred = false
    var catalogSuggestions: [GroceryCatalogItem] = []
    var isSearchingCatalog = false
    var duplicateWarning: String?

    private let repository: ShoppingRepository
    private let catalogRepository: GroceryCatalogRepository
    private let listRepository: ShoppingListRepository
    private let pantryRepository: PantryRepository
    private let householdId: UUID
    private let userId: UUID
    private let listId: UUID?
    private var observationTask: Task<Void, Never>?
    private var catalogSearchTask: Task<Void, Never>?
    private var isAdding = false
    private var pantryItems: [PantryItem] = []

    var pendingItems: [ShoppingItem] {
        items.filter { !$0.completed }
    }

    var completedItems: [ShoppingItem] {
        items.filter { $0.completed }
    }

    var transferableItems: [ShoppingItem] {
        items.filter { $0.completed && !$0.transferred }
    }

    var allItemsCompleted: Bool {
        !items.isEmpty && pendingItems.isEmpty
    }

    var hasTransferableItems: Bool {
        !transferableItems.isEmpty
    }

    init(
        repository: ShoppingRepository,
        catalogRepository: GroceryCatalogRepository = SupabaseGroceryCatalogRepository(),
        listRepository: ShoppingListRepository = SupabaseShoppingListRepository(),
        pantryRepository: PantryRepository = SupabasePantryRepository(),
        householdId: UUID,
        userId: UUID,
        listId: UUID? = nil
    ) {
        self.repository = repository
        self.catalogRepository = catalogRepository
        self.listRepository = listRepository
        self.pantryRepository = pantryRepository
        self.householdId = householdId
        self.userId = userId
        self.listId = listId
    }

    func loadItems() async {
        do {
            if let listId {
                items = try await repository.fetchByList(listId: listId)
            } else {
                items = try await repository.fetchAll(householdId: householdId)
            }
            // Derive list transfer status from per-item flags
            let completed = items.filter { $0.completed }
            if !completed.isEmpty {
                listTransferred = completed.allSatisfy(\.transferred)
            }
        } catch {
            ToastManager.shared.show("Failed to load shopping items", style: .error)
        }

        // Load pantry items for duplicate detection
        pantryItems = (try? await pantryRepository.fetchAll(householdId: householdId)) ?? []
    }

    func checkDuplicate(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            duplicateWarning = nil
            return
        }
        if let match = pantryItems.first(where: {
            !$0.archived && $0.name.localizedCaseInsensitiveContains(trimmed)
        }) {
            duplicateWarning = "\(match.name) is already in your pantry (\(match.quantity.formatted()) \(match.unit.abbreviation))"
        } else {
            duplicateWarning = nil
        }
    }

    func startObserving() {
        observationTask = Task {
            if let listId {
                for await updated in repository.observeListChanges(listId: listId) {
                    self.items = updated
                }
            } else {
                for await updated in repository.observeChanges(householdId: householdId) {
                    self.items = updated
                }
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    func addItem() async {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }

        newItemName = ""

        // Re-fetch to avoid race with stale items
        do {
            if let listId {
                items = try await repository.fetchByList(listId: listId)
            } else {
                items = try await repository.fetchAll(householdId: householdId)
            }
        } catch {
            ToastManager.shared.show("Failed to load items", style: .error)
            return
        }

        // If the same item already exists (pending), increment its quantity
        if let index = items.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && !$0.completed }) {
            var existing = items[index]
            existing.quantity += 1
            existing.updatedAt = .now
            do {
                let saved = try await repository.update(existing)
                items[index] = saved
                ToastManager.shared.show("\(saved.name) ×\(Int(saved.quantity))", style: .success)
            } catch {
                ToastManager.shared.show("Failed to update item", style: .error)
            }
            return
        }

        let item = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: name,
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )

        do {
            let saved = try await repository.add(item)
            items.append(saved)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ToastManager.shared.show("\(saved.name) added", style: .success)
        } catch {
            ToastManager.shared.show("Failed to add item", style: .error)
        }
    }

    func addCatalogItem(_ catalogItem: GroceryCatalogItem) async {
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }

        // Re-fetch to avoid race with stale items
        do {
            if let listId {
                items = try await repository.fetchByList(listId: listId)
            } else {
                items = try await repository.fetchAll(householdId: householdId)
            }
        } catch {
            ToastManager.shared.show("Failed to load items", style: .error)
            return
        }

        // If the same item already exists (pending), increment its quantity
        if let index = items.firstIndex(where: { $0.name.caseInsensitiveCompare(catalogItem.name) == .orderedSame && !$0.completed }) {
            var existing = items[index]
            existing.quantity += 1
            existing.updatedAt = .now
            do {
                let saved = try await repository.update(existing)
                items[index] = saved
                ToastManager.shared.show("\(saved.name) ×\(Int(saved.quantity))", style: .success)
            } catch {
                ToastManager.shared.show("Failed to update item", style: .error)
            }
            return
        }

        let item = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: catalogItem.name,
            quantity: 1,
            unit: catalogItem.defaultUnit,
            category: catalogItem.defaultCategory,
            completed: false,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )

        do {
            let saved = try await repository.add(item)
            items.append(saved)
            ToastManager.shared.show("\(saved.name) added", style: .success)
        } catch {
            ToastManager.shared.show("Failed to add item", style: .error)
        }
    }

    func toggleComplete(_ item: ShoppingItem) async {
        var updated = item
        updated.completed.toggle()
        updated.updatedAt = .now
        do {
            let saved = try await repository.update(updated)
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items[index] = saved
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            ToastManager.shared.show("Failed to update item", style: .error)
        }
    }

    func deleteItem(_ item: ShoppingItem) async {
        do {
            try await repository.delete(itemId: item.itemId)
            items.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("\(item.name) removed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to delete item", style: .error)
        }
    }

    func markAllComplete() async {
        for item in pendingItems {
            await toggleComplete(item)
        }
    }

    // MARK: - Transfer Status

    func refreshTransferredStatus() async {
        guard let listId else { return }
        // Reload items to get updated transferred flags
        do {
            items = try await repository.fetchByList(listId: listId)
        } catch {
            ToastManager.shared.show("Could not refresh transfer status", style: .error)
        }
        // List is fully transferred only when all completed items are transferred
        let completed = items.filter { $0.completed }
        listTransferred = !completed.isEmpty && completed.allSatisfy(\.transferred)
    }

    // MARK: - Inline Catalog Search

    func searchCatalog() {
        catalogSearchTask?.cancel()

        let query = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            catalogSuggestions = []
            isSearchingCatalog = false
            return
        }

        catalogSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearchingCatalog = true
            let results = (try? await catalogRepository.search(query: query, limit: 5)) ?? []
            guard !Task.isCancelled else { return }

            catalogSuggestions = results
            isSearchingCatalog = false
        }
    }

    func clearSuggestions() {
        catalogSuggestions = []
        isSearchingCatalog = false
        catalogSearchTask?.cancel()
    }
}
