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
    var pantryMatchForNewItem: PantryItem?
    var showDuplicateConfirmation = false
    var pantryMatchIds: [UUID: UUID] = [:]
    var itemToReject: ShoppingItem?
    var rejectReasonText = ""
    var showRejectReasonPrompt = false

    private let repository: ShoppingRepository
    private let catalogRepository: GroceryCatalogRepository
    private let listRepository: ShoppingListRepository
    private let pantryRepository: PantryRepository
    private let householdId: UUID
    private let userId: UUID
    private let userRole: UserRole
    private let approvalService: ApprovalService
    private let listId: UUID?

    var isAdmin: Bool { userRole == .admin }
    private var observationTask: Task<Void, Never>?
    private var widgetSyncTask: Task<Void, Never>?
    private var catalogSearchTask: Task<Void, Never>?
    private var isAdding = false
    private(set) var pantryItems: [PantryItem] = []
    private var pendingFreeTextName: String?
    private var pendingCatalogItem: GroceryCatalogItem?

    /// IDs of shopping items currently involved in an async mutation.
    /// Views use this to disable per-item buttons while a call is in flight.
    private(set) var inflightItemIds: Set<UUID> = []
    /// True while `markAllComplete` is running.
    private(set) var isMarkingAllComplete = false

    var pendingItems: [ShoppingItem] {
        items.filter { $0.isApproved && !$0.completed }
    }

    var completedItems: [ShoppingItem] {
        items.filter { $0.isApproved && $0.completed }
    }

    var awaitingApprovalItems: [ShoppingItem] {
        items.filter { $0.approvalStatus == .pending }
    }

    var myRejectedItems: [ShoppingItem] {
        items.filter { $0.approvalStatus == .rejected && $0.createdBy == userId }
    }

    var transferableItems: [ShoppingItem] {
        items.filter { $0.isApproved && $0.completed && !$0.transferred }
    }

    var allItemsCompleted: Bool {
        !items.isEmpty && pendingItems.isEmpty
    }

    /// True when at least one completed item can move to pantry.
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
        userRole: UserRole = .member,
        approvalService: ApprovalService = ApprovalService(),
        listId: UUID? = nil
    ) {
        self.repository = repository
        self.catalogRepository = catalogRepository
        self.listRepository = listRepository
        self.pantryRepository = pantryRepository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
        self.approvalService = approvalService
        self.listId = listId
    }

    func approveItem(_ item: ShoppingItem) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            let approved = try await approvalService.approveShoppingItem(itemId: item.itemId)
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items[index] = approved
            }
            ToastManager.shared.show("\(approved.name) approved", style: .success)
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve \(item.name)"),
                style: .error
            )
        }
    }

    func beginRejectItem(_ item: ShoppingItem) {
        itemToReject = item
        rejectReasonText = ""
        showRejectReasonPrompt = true
    }

    func confirmRejectItem() async {
        guard let item = itemToReject else { return }
        let trimmed = rejectReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        itemToReject = nil
        rejectReasonText = ""
        showRejectReasonPrompt = false
        await rejectItem(item, reason: trimmed.isEmpty ? nil : trimmed)
    }

    func cancelRejectItem() {
        itemToReject = nil
        rejectReasonText = ""
        showRejectReasonPrompt = false
    }

    func rejectItem(_ item: ShoppingItem, reason: String? = nil) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            let rejected = try await approvalService.rejectShoppingItem(itemId: item.itemId, reason: reason)
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items[index] = rejected
            }
            ToastManager.shared.show("\(rejected.name) rejected", style: .success)
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "reject \(item.name)"),
                style: .error
            )
        }
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
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "load this list"),
                style: .error
            )
        }

        // Load pantry items for duplicate detection
        pantryItems = (try? await pantryRepository.fetchAll(householdId: householdId)) ?? []
        scheduleShoppingListWidgetSync()
    }

    func confirmAddDespiteDuplicate() async {
        showDuplicateConfirmation = false
        pantryMatchForNewItem = nil
        duplicateWarning = nil

        if let name = pendingFreeTextName {
            pendingFreeTextName = nil
            await performAddFreeText(name: name)
        } else if let catalog = pendingCatalogItem {
            pendingCatalogItem = nil
            await performAddCatalogItem(catalog)
        }
    }

    func cancelDuplicateConfirmation() {
        showDuplicateConfirmation = false
        pantryMatchForNewItem = nil
        pendingFreeTextName = nil
        pendingCatalogItem = nil
    }

    func checkDuplicate(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            duplicateWarning = nil
            return
        }
        if let match = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: trimmed) {
            duplicateWarning = ShoppingListAddBehavior.inPantryInlineMessage(for: match)
        } else {
            duplicateWarning = nil
        }
    }

    func pantrySuggestionSubtitle(for catalog: GroceryCatalogItem) -> String? {
        guard let match = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: catalog.name) else { return nil }
        return ShoppingListAddBehavior.inPantrySuggestionSubtitle(for: match)
    }

    private func showAddedToListMessage(for item: ShoppingItem) {
        let base = isAdmin ? "\(item.name) added" : "\(item.name) submitted for approval"
        if let pantry = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: item.name) {
            ToastManager.shared.show(
                "\(base). \(ShoppingListAddBehavior.inPantryInlineMessage(for: pantry)).",
                style: .success
            )
        } else {
            ToastManager.shared.show(base, style: .success)
        }
    }

    func startObserving() {
        observationTask = Task {
            if let listId {
                for await updated in repository.observeListChanges(listId: listId) {
                    self.items = ShoppingItemsMerge.merging(server: updated, preservingLocal: self.items)
                    self.scheduleShoppingListWidgetSync()
                }
            } else {
                for await updated in repository.observeChanges(householdId: householdId) {
                    self.items = ShoppingItemsMerge.merging(server: updated, preservingLocal: self.items)
                    self.scheduleShoppingListWidgetSync()
                }
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
        widgetSyncTask?.cancel()
        widgetSyncTask = nil
    }

    /// Debounced full-household refresh (realtime bursts).
    private func scheduleShoppingListWidgetSync() {
        widgetSyncTask?.cancel()
        let hid = householdId
        let listRepo = listRepository
        let shopRepo = repository
        widgetSyncTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await pushShoppingListWidgetSnapshot(householdId: hid, listRepo: listRepo, shopRepo: shopRepo)
        }
    }

    /// Immediate widget snapshot from server (call after local mutations so the widget doesn’t wait on realtime).
    private func pushShoppingListWidgetSnapshot(
        householdId hid: UUID,
        listRepo: ShoppingListRepository,
        shopRepo: ShoppingRepository
    ) async {
        guard let lists = try? await listRepo.fetchAll(householdId: hid),
              let items = try? await shopRepo.fetchAll(householdId: hid) else { return }
        ShoppingListWidgetDataStore.shared.sync(lists: lists, items: items)
    }

    private func pushShoppingListWidgetSnapshotFromServer() {
        Task {
            await pushShoppingListWidgetSnapshot(
                householdId: householdId,
                listRepo: listRepository,
                shopRepo: repository
            )
        }
    }

    // MARK: - Add Item (free text)

    func addItem(overrideName: String? = nil) async {
        let name = (overrideName ?? newItemName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isAdding else { return }

        // Check pantry for duplicates — prompt confirmation before adding
        if let match = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: name) {
            pantryMatchForNewItem = match
            pendingFreeTextName = name
            pendingCatalogItem = nil
            duplicateWarning = ShoppingListAddBehavior.pantryMatchMessageWithTime(for: match)
            showDuplicateConfirmation = true
            return
        }

        await performAddFreeText(name: name)
    }

    private func performAddFreeText(name: String) async {
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }

        // Clear UI immediately so user sees feedback
        newItemName = ""
        clearSuggestions()

        guard await refreshItemsBeforeAdd() else { return }

        // Same name already on the list (any status, not completed) → increment quantity
        if let existing = items.first(where: { item in
            !item.completed
                && GroceryCatalogSearchRanker.shoppingNamesMatch(item.name, name)
        }) {
            await adjustQuantity(itemId: existing.itemId, delta: 1)
            return
        }

        let item = ShoppingItem.newFreeTextLine(
            name: name,
            householdId: householdId,
            listId: listId,
            createdBy: userId,
            approvalStatus: isAdmin ? .approved : .pending
        )

        do {
            let saved = try await repository.add(item)
            await reloadItemsAfterMutation(fallback: saved)
            trackPantryMatch(for: saved)
            EngagementStore.shared.recordShoppingAction()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddedToListMessage(for: saved)
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "add that item"),
                style: .error
            )
        }
    }

    // MARK: - Add Item (catalog suggestion)

    func addCatalogItem(_ catalogItem: GroceryCatalogItem) async {
        guard !isAdding else { return }

        // Check pantry for duplicates — prompt confirmation before adding
        if let match = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: catalogItem.name) {
            pantryMatchForNewItem = match
            pendingCatalogItem = catalogItem
            pendingFreeTextName = nil
            duplicateWarning = ShoppingListAddBehavior.pantryMatchMessageWithTime(for: match)
            showDuplicateConfirmation = true
            return
        }

        await performAddCatalogItem(catalogItem)
    }

    private func performAddCatalogItem(_ catalogItem: GroceryCatalogItem) async {
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }

        // Clear UI immediately so user sees feedback
        newItemName = ""
        clearSuggestions()

        guard await refreshItemsBeforeAdd() else { return }

        // Same catalog product already on the list → increment quantity.
        // Match by catalog UUID first; fall back to exact name for legacy free-text rows.
        if let existing = items.first(where: { item in
            !item.completed && listDuplicate(item, catalogItem: catalogItem)
        }) {
            await adjustQuantity(itemId: existing.itemId, delta: 1)
            return
        }

        let item = ShoppingItem.newCatalogLine(
            from: catalogItem,
            householdId: householdId,
            listId: listId,
            createdBy: userId,
            approvalStatus: isAdmin ? .approved : .pending
        )
        items.append(item)

        do {
            let saved = try await repository.add(item)
            notifyIfCatalogLinkMissing(expected: catalogItem.catalogItemId, saved: saved)
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items[index] = saved
            } else {
                await reloadItemsAfterMutation(fallback: saved)
            }
            trackPantryMatch(for: saved)
            EngagementStore.shared.recordShoppingAction()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddedToListMessage(for: saved)
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            items.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "add that item"),
                style: .error
            )
        }
    }

    /// True when `existing` shopping-list row is the same product as `catalogItem`.
    /// Uses catalog UUID when the existing row has one; otherwise exact name match.
    private func listDuplicate(_ existing: ShoppingItem, catalogItem: GroceryCatalogItem) -> Bool {
        if let existingCatalogId = existing.catalogItemId {
            return existingCatalogId == catalogItem.catalogItemId
        }
        return GroceryCatalogSearchRanker.shoppingNamesMatch(existing.name, catalogItem.name)
    }

    private func resolveCatalogMatch(for name: String) async -> GroceryCatalogItem? {
        guard name.count >= 2 else { return nil }
        let raw = (try? await catalogRepository.search(query: name, limit: 20)) ?? []
        return GroceryCatalogSearchRanker.exactMatch(in: raw, query: name)
    }

    func adjustQuantity(itemId: UUID, delta: Int) async {
        guard let index = items.firstIndex(where: { $0.itemId == itemId }) else { return }
        let item = items[index]
        guard !item.completed else { return }
        guard inflightItemIds.insert(itemId).inserted else { return }
        defer { inflightItemIds.remove(itemId) }

        if delta < 0, item.quantity <= 1 {
            inflightItemIds.remove(itemId)
            await deleteItem(item)
            return
        }

        var updated = item
        guard ShoppingListAddBehavior.applyQuantityChange(to: &updated, delta: delta) else { return }
        do {
            let saved = try await repository.update(updated)
            items[index] = saved
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "save that change"),
                style: .error
            )
        }
    }

    @discardableResult
    private func refreshItemsBeforeAdd() async -> Bool {
        do {
            let server: [ShoppingItem]
            if let listId {
                server = try await repository.fetchByList(listId: listId)
            } else {
                server = try await repository.fetchAll(householdId: householdId)
            }
            items = ShoppingItemsMerge.merging(server: server, preservingLocal: items)
            return true
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "load items"),
                style: .error
            )
            return false
        }
    }

    private func reloadItemsAfterMutation(fallback: ShoppingItem) async {
        do {
            if let listId {
                items = try await repository.fetchByList(listId: listId)
            } else {
                items = try await repository.fetchAll(householdId: householdId)
            }
        } catch {
            if !items.contains(where: { $0.itemId == fallback.itemId }) {
                items.append(fallback)
            }
        }
    }

    private func notifyIfCatalogLinkMissing(expected: UUID, saved: ShoppingItem) {
        guard saved.catalogItemId != expected else { return }
        ToastManager.shared.show(
            "Added \(saved.name), but the catalog link did not save. In Supabase: Settings → API → Reload schema cache, then try again.",
            style: .warning
        )
    }

    private func trackPantryMatch(for shoppingItem: ShoppingItem) {
        if let match = ShoppingListAddBehavior.pantryMatch(in: pantryItems, name: shoppingItem.name) {
            pantryMatchIds[shoppingItem.itemId] = match.itemId
        }
    }

    func toggleComplete(_ item: ShoppingItem, refreshWidget: Bool = true) async {
        guard item.isApproved else { return }
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        var updated = item
        updated.completed.toggle()
        updated.updatedAt = .now
        do {
            let saved = try await repository.update(updated)
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items[index] = saved
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if refreshWidget { pushShoppingListWidgetSnapshotFromServer() }
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "save that change"),
                style: .error
            )
        }
    }

    func deleteItem(_ item: ShoppingItem) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            try await repository.delete(itemId: item.itemId)
            items.removeAll { $0.itemId == item.itemId }
            ToastManager.shared.show("\(item.name) removed", style: .success)
            pushShoppingListWidgetSnapshotFromServer()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "remove that item"),
                style: .error
            )
        }
    }

    func markAllComplete() async {
        guard !isMarkingAllComplete else { return }
        isMarkingAllComplete = true
        defer { isMarkingAllComplete = false }
        for item in pendingItems {
            await toggleComplete(item, refreshWidget: false)
        }
        pushShoppingListWidgetSnapshotFromServer()
    }

    // MARK: - Transfer Status

    func refreshTransferredStatus() async {
        guard let listId else { return }
        // Reload items to get updated transferred flags
        do {
            items = try await repository.fetchByList(listId: listId)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "refresh transfer status"),
                style: .error
            )
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

        // Immediately re-rank existing suggestions against the updated query
        // so stale results from a previous search don't appear in the wrong order.
        // e.g. typing "coconut water" re-ranks the "coconut" results to put
        // "Coconut Water" first instead of "Coconut".
        if !catalogSuggestions.isEmpty {
            let reranked = GroceryCatalogSearchRanker.suggestions(
                from: catalogSuggestions, query: query, limit: 8
            )
            // Drop items that have zero relevance to the current query
            let lowerQuery = query.lowercased()
            catalogSuggestions = reranked.filter { item in
                let lowerName = item.name.lowercased()
                return lowerName.contains(lowerQuery)
                    || lowerQuery.contains(lowerName)
                    || lowerQuery.split(separator: " ").allSatisfy { lowerName.contains($0) }
            }
        }

        catalogSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearchingCatalog = true
            let raw = (try? await catalogRepository.search(query: query, limit: 20)) ?? []
            guard !Task.isCancelled else { return }

            catalogSuggestions = GroceryCatalogSearchRanker.suggestions(from: raw, query: query, limit: 8)
            isSearchingCatalog = false
        }
    }

    /// Cancels any in-flight debounced search so the suggestion list stays frozen.
    /// Call this synchronously before handling a button tap to prevent the search
    /// from updating suggestions mid-interaction.
    func cancelPendingSearch() {
        catalogSearchTask?.cancel()
    }

    func clearSuggestions() {
        catalogSuggestions = []
        isSearchingCatalog = false
        catalogSearchTask?.cancel()
    }

    /// Quick add to pantry from the list (spec: swipe “Move to pantry”) without the full transfer sheet.
    func quickMoveToPantry(_ item: ShoppingItem) async {
        guard !item.transferred else { return }
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }

        var working = item
        if !working.completed {
            working.completed = true
            working.updatedAt = .now
            do {
                working = try await repository.update(working)
                if let idx = items.firstIndex(where: { $0.itemId == item.itemId }) {
                    items[idx] = working
                }
            } catch {
                ToastManager.shared.show(
                    ErrorHandler.userMessage(for: error, action: "update that item"),
                    style: .error
                )
                return
            }
        }

        let category = working.category ?? "Other"
        let qty = working.quantity

        do {
            // Always create new pantry item (no auto-merging)
            let newItem = PantryItem(
                itemId: UUID(),
                householdId: householdId,
                name: working.name,
                quantity: qty,
                unit: working.unit ?? .pcs,
                category: category,
                storageLocation: .shelf,
                expiryDate: nil,
                costPerUnitMinor: nil,
                lowStockThreshold: 1,
                createdBy: userId,
                createdAt: .now,
                updatedAt: .now,
                archived: false,
                lastQuantityUpdateDate: .now,
                expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: category)
            )
            _ = try await pantryRepository.add(newItem)

            _ = try await repository.markTransferred(itemId: working.itemId)
            if let listId {
                await syncListTransferredFlagIfNeeded(listId: listId)
            }
            await loadItems()
            pantryItems = (try? await pantryRepository.fetchAll(householdId: householdId)) ?? pantryItems
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            BetaTelemetryService.shared.logFirstTransfer()
            ToastManager.shared.show("\(working.name) moved to pantry", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "move to pantry"),
                style: .error
            )
        }
    }

    private func syncListTransferredFlagIfNeeded(listId: UUID) async {
        do {
            let allItems = try await repository.fetchByList(listId: listId)
            let completed = allItems.filter(\.completed)
            let hasUntransferred = completed.contains { !$0.transferred }
            if !hasUntransferred, !completed.isEmpty {
                let lists = try await listRepository.fetchAll(householdId: householdId)
                if var list = lists.first(where: { $0.listId == listId }) {
                    list.transferred = true
                    _ = try await listRepository.update(list)
                }
            }
        } catch {
            // best-effort
        }
    }
}
