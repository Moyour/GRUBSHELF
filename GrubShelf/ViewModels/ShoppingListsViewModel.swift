import Foundation
import Observation
import UIKit

/// Aggregates for the Shop hub summary (active lists only — excludes transferred lists from item totals).
struct ShoppingHubSummary: Equatable {
    let listCount: Int
    let pendingTotal: Int
    let completedTotal: Int

    static func make(lists: [ShoppingList], listItemCounts: [UUID: (pending: Int, completed: Int)]) -> ShoppingHubSummary {
        var pending = 0
        var completed = 0
        for list in lists where !list.transferred {
            let c = listItemCounts[list.listId] ?? (0, 0)
            pending += c.pending
            completed += c.completed
        }
        return ShoppingHubSummary(
            listCount: lists.count,
            pendingTotal: pending,
            completedTotal: completed
        )
    }
}

@MainActor
@Observable
final class ShoppingListsViewModel {
    var lists: [ShoppingList] = []
    var hasLoaded = false
    var showCreateSheet = false
    var newListName: String = ""
    var listItemCounts: [UUID: (pending: Int, completed: Int)] = [:]
    /// Latest fetch of household shopping items (used for Home list preview).
    private(set) var cachedShoppingItems: [ShoppingItem] = []
    var errorMessage: String?

    private let listRepository: ShoppingListRepository
    private let shoppingRepository: ShoppingRepository
    private let catalogRepository: GroceryCatalogRepository
    let householdId: UUID
    let userId: UUID

    var hubSummary: ShoppingHubSummary {
        ShoppingHubSummary.make(lists: lists, listItemCounts: listItemCounts)
    }

    // MARK: - Active list (inline expanded)

    /// Most recent non-transferred list (the "active" one shown expanded inline).
    var activeList: ShoppingList? {
        ShoppingListWidgetSnapshotBuilder.orderedActiveLists(lists: lists).first
    }

    /// All lists except the active one.
    var otherLists: [ShoppingList] {
        guard let active = activeList else { return lists }
        return lists.filter { $0.listId != active.listId }
    }

    /// Items for the inline-expanded active list.
    var activeListItems: [ShoppingItem] = []
    var activeListNewItemName: String = ""
    var isSearchingActiveCatalog = false
    var activeCatalogSuggestions: [GroceryCatalogItem] = []
    private var activeCatalogSearchTask: Task<Void, Never>?

    var activeListPendingItems: [ShoppingItem] {
        activeListItems.filter { !$0.completed }
    }

    var activeListCompletedItems: [ShoppingItem] {
        activeListItems.filter { $0.completed }
    }

    func loadActiveListItems() async {
        guard let active = activeList else {
            activeListItems = []
            return
        }
        do {
            activeListItems = try await shoppingRepository.fetchByList(listId: active.listId)
        } catch {
            // Fall back to cached items filtered by this list
            activeListItems = cachedShoppingItems.filter { $0.listId == active.listId }
        }
    }

    func toggleActiveItem(_ item: ShoppingItem) async {
        var updated = item
        updated.completed.toggle()
        updated.updatedAt = .now
        do {
            let saved = try await shoppingRepository.update(updated)
            if let index = activeListItems.firstIndex(where: { $0.itemId == item.itemId }) {
                activeListItems[index] = saved
            }
            // Keep hub counts in sync
            await loadItemCounts()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            ToastManager.shared.show("Couldn't save that change", style: .error)
        }
    }

    func addItemToActiveList() async {
        guard let active = activeList else { return }
        let name = activeListNewItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        activeListNewItemName = ""
        activeCatalogSuggestions = []

        // If the same item already exists (pending), increment its quantity
        if let index = activeListItems.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && !$0.completed }) {
            var existing = activeListItems[index]
            existing.quantity += 1
            existing.updatedAt = .now
            do {
                let saved = try await shoppingRepository.update(existing)
                activeListItems[index] = saved
                await loadItemCounts()
                ToastManager.shared.show("\(saved.name) ×\(Int(saved.quantity))", style: .success)
            } catch {
                ToastManager.shared.show("Couldn't save that change", style: .error)
            }
            return
        }

        let item = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: active.listId,
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
            let saved = try await shoppingRepository.add(item)
            activeListItems.append(saved)
            await loadItemCounts()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ToastManager.shared.show("\(saved.name) added", style: .success)
        } catch {
            ToastManager.shared.show("Couldn't add that item", style: .error)
        }
    }

    func addActiveCatalogItem(_ catalogItem: GroceryCatalogItem) async {
        guard let active = activeList else { return }

        activeListNewItemName = ""
        activeCatalogSuggestions = []

        let item = ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: active.listId,
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
            let saved = try await shoppingRepository.add(item)
            activeListItems.append(saved)
            await loadItemCounts()
            ToastManager.shared.show("\(saved.name) added", style: .success)
        } catch {
            ToastManager.shared.show("Couldn't add that item", style: .error)
        }
    }

    func searchActiveCatalog() {
        activeCatalogSearchTask?.cancel()
        let query = activeListNewItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            activeCatalogSuggestions = []
            isSearchingActiveCatalog = false
            return
        }
        activeCatalogSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearchingActiveCatalog = true
            let results = (try? await catalogRepository.search(query: query, limit: 5)) ?? []
            guard !Task.isCancelled else { return }
            activeCatalogSuggestions = results
            isSearchingActiveCatalog = false
        }
    }

    /// Primary list for the Home dashboard: same ordering as Shop / widget (pinned list first, then newest).
    /// Includes every non-transferred item; pending rows first, then completed (alphabetical within each group).
    var homePrimaryListPreview: (list: ShoppingList, items: [ShoppingItem])? {
        let active = ShoppingListWidgetSnapshotBuilder.orderedActiveLists(lists: lists)
        guard let list = active.first else { return nil }
        let mine = cachedShoppingItems.filter { $0.listId == list.listId && !$0.transferred }
        let sorted = mine.sorted { lhs, rhs in
            if lhs.completed != rhs.completed { return !lhs.completed && rhs.completed }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return (list, sorted)
    }

    private var observationTask: Task<Void, Never>?
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    init(
        listRepository: ShoppingListRepository,
        shoppingRepository: ShoppingRepository,
        catalogRepository: GroceryCatalogRepository = SupabaseGroceryCatalogRepository(),
        householdId: UUID,
        userId: UUID
    ) {
        self.listRepository = listRepository
        self.shoppingRepository = shoppingRepository
        self.catalogRepository = catalogRepository
        self.householdId = householdId
        self.userId = userId
    }

    func loadLists(forceRefresh: Bool = false) async {
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        do {
            lists = try await listRepository.fetchAll(householdId: householdId)
            await loadItemCounts()
            hasLoaded = true
            lastLoadedAt = .now
        } catch {
            hasLoaded = true
            switch ErrorHandler.classify(error) {
            case .networkFailure:
                ToastManager.shared.show("You're offline — showing cached data", style: .error)
            case .serverError:
                ToastManager.shared.show("Server is temporarily unavailable", style: .error)
            default:
                errorMessage = "Failed to load lists: \(error.localizedDescription)"
            }
        }
    }

    private func loadItemCounts() async {
        do {
            let allItems = try await shoppingRepository.fetchAll(householdId: householdId)
            cachedShoppingItems = allItems
            var counts: [UUID: (pending: Int, completed: Int)] = [:]
            for item in allItems {
                guard let listId = item.listId else { continue }
                let current = counts[listId] ?? (pending: 0, completed: 0)
                if item.completed {
                    counts[listId] = (pending: current.pending, completed: current.completed + 1)
                } else {
                    counts[listId] = (pending: current.pending + 1, completed: current.completed)
                }
            }
            listItemCounts = counts
            ShoppingListWidgetDataStore.shared.sync(lists: lists, items: allItems)
        } catch {
            // Non-critical — item counts are supplementary, list still displays
        }
    }

    @discardableResult
    func createList() async -> ShoppingList? {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let list = ShoppingList(
            listId: UUID(),
            householdId: householdId,
            name: name,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )

        newListName = ""
        errorMessage = nil

        do {
            let saved = try await listRepository.add(list)
            lists.insert(saved, at: 0)
            await loadItemCounts()
            ToastManager.shared.show("\(saved.name) created", style: .success)
            return saved
        } catch {
            errorMessage = "Failed to create list: \(error.localizedDescription)"
            ToastManager.shared.show("Failed to create list", style: .error)
            return nil
        }
    }

    func deleteList(_ list: ShoppingList) async {
        do {
            try await listRepository.delete(listId: list.listId)
            lists.removeAll { $0.listId == list.listId }
            listItemCounts.removeValue(forKey: list.listId)
            if ShoppingListWidgetPreferences.pinnedListId() == list.listId {
                ShoppingListWidgetPreferences.clearPinnedList()
            }
            await loadItemCounts()
            ToastManager.shared.show("\(list.name) deleted", style: .success)
        } catch {
            errorMessage = "Failed to delete list: \(error.localizedDescription)"
            ToastManager.shared.show("Failed to delete list", style: .error)
        }
    }

    func startObserving() {
        observationTask = Task {
            for await updated in listRepository.observeChanges(householdId: householdId) {
                self.lists = updated
                await self.loadItemCounts()
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}
