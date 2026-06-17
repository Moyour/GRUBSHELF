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
    private let pantryRepository: PantryRepository
    let householdId: UUID
    let userId: UUID
    let userRole: UserRole
    let isOwner: Bool
    private let approvalService: ApprovalService
    /// Optional gate service for enforcing subscription limits.
    @ObservationIgnored var featureGateService: FeatureGateService?

    /// Pantry snapshot used by the inline transfer flow to detect existing items
    /// (powers the audit/merge step the same way ShoppingListViewModel does).
    private(set) var activeListPantryItems: [PantryItem] = []
    /// Drives the transfer sheet from the expanded active-list card on the Shop hub.
    var showActiveTransferSheet = false

    /// Items eligible to be moved into the pantry: approved + completed + not yet transferred.
    var transferableActiveListItems: [ShoppingItem] {
        activeListItems.filter { $0.isApproved && $0.completed && !$0.transferred }
    }

    /// True when every item on the active list is checked off and at least one can move to pantry.
    var allActiveListItemsCompleted: Bool {
        !activeListItems.isEmpty && activeListPendingItems.isEmpty
    }

    var hasActiveTransferableItems: Bool {
        !transferableActiveListItems.isEmpty
    }

    var isAdmin: Bool { userRole == .admin }

    private var permissionContext: HouseholdPermissionContext {
        HouseholdPermissionContext(role: userRole, isOwner: isOwner)
    }

    var canCreateShoppingList: Bool {
        PermissionService.canPerform(.createShoppingList, context: permissionContext)
    }

    var canDeleteShoppingList: Bool {
        PermissionService.canPerform(.deleteShoppingList, context: permissionContext)
    }

    /// IDs of shopping items on the active list currently being mutated async.
    private(set) var inflightItemIds: Set<UUID> = []
    /// True while `createList` is running (prevents duplicate list creation).
    private(set) var isCreatingList = false
    /// List IDs currently being deleted.
    private(set) var deletingListIds: Set<UUID> = []
    /// True while an item add to the active list is in flight.
    private(set) var isAddingToActiveList = false

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
    var activeItemToReject: ShoppingItem?
    var activeRejectReasonText = ""
    var showActiveRejectReasonPrompt = false
    var activeListNewItemName: String = ""
    var activePantryWarning: String?
    var isSearchingActiveCatalog = false
    var activeCatalogSuggestions: [GroceryCatalogItem] = []
    private var activeCatalogSearchTask: Task<Void, Never>?

    var activeListPendingItems: [ShoppingItem] {
        activeListItems.filter { $0.isApproved && !$0.completed }
    }

    var activeListCompletedItems: [ShoppingItem] {
        activeListItems.filter { $0.isApproved && $0.completed }
    }

    var activeListAwaitingApproval: [ShoppingItem] {
        activeListItems.filter { $0.approvalStatus == .pending }
    }

    var myActiveListRejectedItems: [ShoppingItem] {
        activeListItems.filter { $0.approvalStatus == .rejected && $0.createdBy == userId }
    }

    func loadActiveListItems() async {
        guard let active = activeList else {
            activeListItems = []
            activeListPantryItems = []
            return
        }
        activeListPantryItems = (try? await pantryRepository.fetchAll(householdId: householdId)) ?? activeListPantryItems
        do {
            activeListItems = try await shoppingRepository.fetchByList(listId: active.listId)
        } catch {
            // Fall back to cached items filtered by this list
            activeListItems = cachedShoppingItems.filter { $0.listId == active.listId }
        }
    }

    func checkActivePantryDuplicate(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            activePantryWarning = nil
            return
        }
        if let match = ShoppingListAddBehavior.pantryMatch(in: activeListPantryItems, name: trimmed) {
            activePantryWarning = ShoppingListAddBehavior.inPantryInlineMessage(for: match)
        } else {
            activePantryWarning = nil
        }
    }

    func activePantrySuggestionSubtitle(for catalog: GroceryCatalogItem) -> String? {
        guard let match = ShoppingListAddBehavior.pantryMatch(in: activeListPantryItems, name: catalog.name) else { return nil }
        return ShoppingListAddBehavior.inPantrySuggestionSubtitle(for: match)
    }

    private func showAddedToActiveListMessage(for item: ShoppingItem) {
        let base = isAdmin ? "\(item.name) added" : "\(item.name) submitted for approval"
        if let pantry = ShoppingListAddBehavior.pantryMatch(in: activeListPantryItems, name: item.name) {
            ToastManager.shared.show(
                "\(base). \(ShoppingListAddBehavior.inPantryInlineMessage(for: pantry)).",
                style: .success
            )
        } else {
            ToastManager.shared.show(base, style: .success)
        }
    }

    func approveActiveItem(_ item: ShoppingItem) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            let approved = try await approvalService.approveShoppingItem(itemId: item.itemId)
            if let index = activeListItems.firstIndex(where: { $0.itemId == item.itemId }) {
                activeListItems[index] = approved
            }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            await loadItemCounts()
            ToastManager.shared.show("\(approved.name) approved", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve \(item.name)"),
                style: .error
            )
        }
    }

    func beginRejectActiveItem(_ item: ShoppingItem) {
        activeItemToReject = item
        activeRejectReasonText = ""
        showActiveRejectReasonPrompt = true
    }

    func confirmRejectActiveItem() async {
        guard let item = activeItemToReject else { return }
        let trimmed = activeRejectReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        activeItemToReject = nil
        activeRejectReasonText = ""
        showActiveRejectReasonPrompt = false
        await rejectActiveItem(item, reason: trimmed.isEmpty ? nil : trimmed)
    }

    func cancelRejectActiveItem() {
        activeItemToReject = nil
        activeRejectReasonText = ""
        showActiveRejectReasonPrompt = false
    }

    func rejectActiveItem(_ item: ShoppingItem, reason: String? = nil) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            let rejected = try await approvalService.rejectShoppingItem(itemId: item.itemId, reason: reason)
            if let index = activeListItems.firstIndex(where: { $0.itemId == item.itemId }) {
                activeListItems[index] = rejected
            }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            await loadItemCounts()
            ToastManager.shared.show("\(rejected.name) rejected", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "reject \(item.name)"),
                style: .error
            )
        }
    }

    func deleteActiveItem(_ item: ShoppingItem) async {
        do {
            try await shoppingRepository.delete(itemId: item.itemId)
            activeListItems.removeAll { $0.itemId == item.itemId }
            await loadItemCounts()
            ToastManager.shared.show("\(item.name) removed", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "remove that item"),
                style: .error
            )
        }
    }

    func toggleActiveItem(_ item: ShoppingItem) async {
        guard item.isApproved else { return }
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
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
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "save that change"),
                style: .error
            )
        }
    }

    func addItemToActiveList() async {
        guard let active = activeList else { return }
        let name = activeListNewItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !isAddingToActiveList else { return }
        isAddingToActiveList = true
        defer { isAddingToActiveList = false }

        activeListNewItemName = ""
        activeCatalogSuggestions = []

        await refreshActiveItemsBeforeAdd()

        // Check for duplicates - if found, INCREMENT quantity instead of creating new item
        // Check both approved AND pending items (same user's pending items should merge)
        if let existingIndex = activeListItems.firstIndex(where: { existing in
            !existing.completed
                && GroceryCatalogSearchRanker.shoppingNamesMatch(existing.name, name)
        }) {
            // Found duplicate - increment quantity instead
            await adjustActiveQuantity(itemId: activeListItems[existingIndex].itemId, delta: 1)
            return
        }

        let item = ShoppingItem.newFreeTextLine(
            name: name,
            householdId: householdId,
            listId: active.listId,
            createdBy: userId,
            approvalStatus: isAdmin ? .approved : .pending
        )

        do {
            let saved = try await shoppingRepository.add(item)
            await loadActiveListItems()
            await loadItemCounts()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddedToActiveListMessage(for: saved)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "add that item"),
                style: .error
            )
        }
    }

    func addActiveCatalogItem(_ catalogItem: GroceryCatalogItem) async {
        guard let active = activeList else { return }
        activeListNewItemName = ""
        activeCatalogSuggestions = []

        guard !isAddingToActiveList else { return }
        isAddingToActiveList = true
        defer { isAddingToActiveList = false }

        await refreshActiveItemsBeforeAdd()

        // Check for duplicates - if found, INCREMENT quantity instead of creating new item
        // Check both approved AND pending items (same user's pending items should merge)
        if let existingIndex = activeListItems.firstIndex(where: { existing in
            !existing.completed
                && GroceryCatalogSearchRanker.shouldCombineShoppingQuantity(existing: existing, catalog: catalogItem)
        }) {
            // Found duplicate - increment quantity instead
            await adjustActiveQuantity(itemId: activeListItems[existingIndex].itemId, delta: 1)
            return
        }

        let item = ShoppingItem.newCatalogLine(
            from: catalogItem,
            householdId: householdId,
            listId: active.listId,
            createdBy: userId,
            approvalStatus: isAdmin ? .approved : .pending
        )
        activeListItems.append(item)

        do {
            let saved = try await shoppingRepository.add(item)
            notifyIfCatalogLinkMissing(expected: catalogItem.catalogItemId, saved: saved)
            if let index = activeListItems.firstIndex(where: { $0.itemId == item.itemId }) {
                activeListItems[index] = saved
            } else {
                await loadActiveListItems()
            }
            await loadItemCounts()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddedToActiveListMessage(for: saved)
        } catch {
            activeListItems.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "add that item"),
                style: .error
            )
        }
    }

    private func refreshActiveItemsBeforeAdd() async {
        guard let active = activeList else { return }
        do {
            let server = try await shoppingRepository.fetchByList(listId: active.listId)
            activeListItems = ShoppingItemsMerge.merging(server: server, preservingLocal: activeListItems)
        } catch {
            activeListItems = cachedShoppingItems.filter { $0.listId == active.listId }
        }
    }

    private func resolveActiveCatalogMatch(for name: String) async -> GroceryCatalogItem? {
        guard name.count >= 2 else { return nil }
        let raw = (try? await catalogRepository.search(query: name, limit: 20)) ?? []
        return GroceryCatalogSearchRanker.exactMatch(in: raw, query: name)
    }

    func adjustActiveQuantity(itemId: UUID, delta: Int) async {
        guard let index = activeListItems.firstIndex(where: { $0.itemId == itemId }) else { return }
        let item = activeListItems[index]
        guard !item.completed else { return }
        guard inflightItemIds.insert(itemId).inserted else { return }
        defer { inflightItemIds.remove(itemId) }

        if delta < 0, item.quantity <= 1 {
            inflightItemIds.remove(itemId)
            await deleteActiveItem(item)
            return
        }

        var updated = item
        guard ShoppingListAddBehavior.applyQuantityChange(to: &updated, delta: delta) else { return }
        do {
            let saved = try await shoppingRepository.update(updated)
            activeListItems[index] = saved
            await loadItemCounts()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "save that change"),
                style: .error
            )
        }
    }

    /// True when catalog matches are showing — free-text submit would add the query string only.
    var activeCatalogSuggestionsVisible: Bool {
        !activeCatalogSuggestions.isEmpty
    }

    private func notifyIfCatalogLinkMissing(expected: UUID, saved: ShoppingItem) {
        guard saved.catalogItemId != expected else { return }
        ToastManager.shared.show(
            "Added \(saved.name), but the catalog link did not save. In Supabase: Settings → API → Reload schema cache, then try again.",
            style: .warning
        )
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
            let raw = (try? await catalogRepository.search(query: query, limit: 20)) ?? []
            guard !Task.isCancelled else { return }
            activeCatalogSuggestions = GroceryCatalogSearchRanker.suggestions(from: raw, query: query, limit: 8)
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
        pantryRepository: PantryRepository = SupabasePantryRepository(),
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member,
        isOwner: Bool = false,
        approvalService: ApprovalService = ApprovalService()
    ) {
        self.listRepository = listRepository
        self.shoppingRepository = shoppingRepository
        self.catalogRepository = catalogRepository
        self.pantryRepository = pantryRepository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
        self.isOwner = isOwner
        self.approvalService = approvalService
    }

    // MARK: - Inline transfer (active list on the Shop hub)

    /// Pre-loads the pantry snapshot so the transfer sheet can immediately decide
    /// between the audit (merge into existing pantry items) and direct-add flows.
    /// Best-effort: if the fetch fails we fall back to an empty list which sends
    /// the user down the direct-add path (the existing detail-screen behaviour).
    func prepareActiveTransfer() async {
        guard hasActiveTransferableItems else { return }
        do {
            activeListPantryItems = try await pantryRepository.fetchAll(householdId: householdId)
        } catch {
            activeListPantryItems = []
        }
        showActiveTransferSheet = true
    }

    /// Re-syncs the inline card after a transfer completes so the CTA disappears
    /// and the "Transferred" badge updates without needing the user to navigate.
    func refreshAfterActiveTransfer() async {
        await loadActiveListItems()
        await loadItemCounts()
        await loadLists(forceRefresh: true)
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
            let message = ErrorHandler.userMessage(for: error, action: "load your shopping lists")
            errorMessage = message
            ToastManager.shared.show(message, style: .error)
        }
    }

    private func loadItemCounts() async {
        do {
            let allItems = try await shoppingRepository.fetchAll(householdId: householdId)
            cachedShoppingItems = allItems
            if isAdmin {
                ApprovalNotificationCoordinator.shared.processPendingItems(
                    pantryItems: [],
                    shoppingItems: allItems,
                    isAdmin: true
                )
            }
            var counts: [UUID: (pending: Int, completed: Int)] = [:]
            for item in allItems where item.isApproved {
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
        guard canCreateShoppingList else {
            ToastManager.shared.show("Only household admins can create shopping lists.", style: .error)
            return nil
        }
        // Check shopping list limit
        if let gate = featureGateService {
            let allowed = await gate.checkLimit(.shoppingLists, householdId: householdId)
            if !allowed { return nil }
        }
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        guard !isCreatingList else { return nil }
        isCreatingList = true
        defer { isCreatingList = false }

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
            BetaTelemetryService.shared.logFirstListCreated()
            return saved
        } catch {
            errorMessage = "Failed to create list: \(error.localizedDescription)"
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "create list"),
                style: .error
            )
            return nil
        }
    }

    func deleteList(_ list: ShoppingList) async {
        guard canDeleteShoppingList else {
            ToastManager.shared.show("Only household admins can delete shopping lists.", style: .error)
            return
        }
        guard deletingListIds.insert(list.listId).inserted else { return }
        defer { deletingListIds.remove(list.listId) }
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
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "delete list"),
                style: .error
            )
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
