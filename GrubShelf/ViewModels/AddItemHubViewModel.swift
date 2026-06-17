import Foundation
import Observation
import UIKit

/// Lightweight entry tracking an item added during the current AddItemHub session.
struct AddedPantryEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    var quantity: Double
    let unit: UnitType
    let category: String
}

@MainActor
@Observable
final class AddItemHubViewModel {
    var searchText = ""

    func triggerSearch() {
        catalogSearchVM.searchText = searchText
        catalogSearchVM.performSearch()
    }

    /// While set, the matching catalog row shows a spinner on its add control.
    var quickAddingCatalogItemId: UUID?
    /// While set, the matching recent-item card shows a spinner.
    var quickAddingRecentItemId: UUID?

    // MARK: - Multi-add state

    /// Lowercased names of items added during this session, for dedup display.
    private var addedItemNamesLower = Set<String>()
    /// Ordered entries of items added during this session.
    private(set) var addedItems: [AddedPantryEntry] = []
    /// Cache of full PantryItem objects for repo updates/deletes.
    private var savedItemsCache: [UUID: PantryItem] = [:]
    /// Drives transient checkmark animation on the most-recently-added recent card.
    var lastAddedRecentItemId: UUID?
    /// Drives transient checkmark animation on the most-recently-added catalog row.
    var lastAddedCatalogItemId: UUID?

    /// Number of items added during this hub session.
    var addedCount: Int { addedItems.count }

    /// Case-insensitive check whether an item name was already added this session.
    func alreadyAdded(_ name: String) -> Bool {
        addedItemNamesLower.contains(name.lowercased())
    }

    var showAddForm = false
    var prefillItem: PantryItem?
    var prefillCatalogItem: GroceryCatalogItem?

    let catalogSearchVM: GroceryCatalogSearchViewModel
    /// Optional gate service for enforcing subscription limits.
    @ObservationIgnored var featureGateService: FeatureGateService?

    private let pantryItems: [PantryItem]
    private let pantryRepository: PantryRepository

    var recentItems: [PantryItem] {
        var seen = Set<String>()
        return pantryItems
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.name.lowercased()).inserted }
            .prefix(10)
            .map { $0 }
    }

    init(
        pantryItems: [PantryItem],
        catalogRepository: GroceryCatalogRepository = SupabaseGroceryCatalogRepository(),
        pantryRepository: PantryRepository = SupabasePantryRepository(),
        featureGateService: FeatureGateService? = nil
    ) {
        self.pantryItems = pantryItems
        self.pantryRepository = pantryRepository
        self.featureGateService = featureGateService
        self.catalogSearchVM = GroceryCatalogSearchViewModel(repository: catalogRepository)
    }

    /// Adds one unit using catalog defaults (same defaults as opening the add form from that row).
    @discardableResult
    func quickAddFromCatalog(
        _ catalogItem: GroceryCatalogItem,
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member
    ) async -> Bool {
        if let gate = featureGateService {
            let allowed = await gate.checkLimit(.pantryItems, householdId: householdId)
            if !allowed { return false }
        }

        quickAddingCatalogItemId = catalogItem.id
        defer { quickAddingCatalogItemId = nil }

        let editor = AddEditPantryItemViewModel(
            repository: pantryRepository,
            householdId: householdId,
            userId: userId,
            userRole: userRole,
            catalogItem: catalogItem
        )
        editor.suppressToast = true
        let success = await editor.save()
        if success {
            let entry = AddedPantryEntry(
                id: editor.lastSavedItemId ?? UUID(),
                name: catalogItem.name,
                quantity: 1,
                unit: catalogItem.defaultUnit,
                category: catalogItem.defaultCategory
            )
            trackAddedItem(entry: entry, pantryItem: editor.lastSavedItem)
            lastAddedCatalogItemId = catalogItem.id
            clearCheckmarkAfterDelay(\.lastAddedCatalogItemId)
        }
        return success
    }

    /// Adds one unit using the recent item's defaults (same path as catalog quick-add).
    @discardableResult
    func quickAddRecent(
        _ item: PantryItem,
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member
    ) async -> Bool {
        if let gate = featureGateService {
            let allowed = await gate.checkLimit(.pantryItems, householdId: householdId)
            if !allowed { return false }
        }

        quickAddingRecentItemId = item.itemId
        defer { quickAddingRecentItemId = nil }

        let editor = AddEditPantryItemViewModel(
            repository: pantryRepository,
            householdId: householdId,
            userId: userId,
            userRole: userRole,
            prefillFrom: item
        )
        editor.suppressToast = true
        let success = await editor.save()
        if success {
            let entry = AddedPantryEntry(
                id: editor.lastSavedItemId ?? UUID(),
                name: item.name,
                quantity: 1,
                unit: item.unit,
                category: item.category
            )
            trackAddedItem(entry: entry, pantryItem: editor.lastSavedItem)
            lastAddedRecentItemId = item.itemId
            clearCheckmarkAfterDelay(\.lastAddedRecentItemId)
        }
        return success
    }

    func openEditForm(for item: PantryItem) {
        prefillCatalogItem = nil
        prefillItem = item
        showAddForm = true
    }

    func openEditForm(for catalogItem: GroceryCatalogItem) {
        prefillItem = nil
        prefillCatalogItem = catalogItem
        showAddForm = true
    }

    // MARK: - Inline edit helpers

    /// Updates the quantity of an already-added item (optimistic UI + repo persist).
    func updateQuantity(itemId: UUID, newQuantity: Double) {
        guard let index = addedItems.firstIndex(where: { $0.id == itemId }) else { return }
        let oldQuantity = addedItems[index].quantity
        addedItems[index].quantity = newQuantity

        guard var cached = savedItemsCache[itemId] else { return }
        cached.quantity = newQuantity
        cached.updatedAt = .now
        savedItemsCache[itemId] = cached
        let capturedItem = cached

        Task { [weak self, pantryRepository] in
            do {
                _ = try await pantryRepository.update(capturedItem)
            } catch {
                if let idx = self?.addedItems.firstIndex(where: { $0.id == itemId }) {
                    self?.addedItems[idx].quantity = oldQuantity
                }
                ToastManager.shared.show("Couldn't update quantity", style: .error)
            }
        }
    }

    /// Removes an added item (optimistic UI + repo delete).
    func removeItem(itemId: UUID) {
        guard let index = addedItems.firstIndex(where: { $0.id == itemId }) else { return }
        let removed = addedItems.remove(at: index)
        addedItemNamesLower.remove(removed.name.lowercased())
        let cachedItem = savedItemsCache.removeValue(forKey: itemId)

        Task { [weak self, pantryRepository] in
            do {
                try await pantryRepository.delete(itemId: itemId)
            } catch {
                self?.addedItems.insert(removed, at: min(index, self?.addedItems.count ?? 0))
                self?.addedItemNamesLower.insert(removed.name.lowercased())
                if let item = cachedItem {
                    self?.savedItemsCache[itemId] = item
                }
                ToastManager.shared.show("Couldn't remove item", style: .error)
            }
        }
    }

    // MARK: - Multi-add helpers

    /// Shows a summary toast with the total count of items added during this session.
    func showDismissSummary() {
        guard addedCount > 0 else { return }
        let label = addedCount == 1 ? "1 item added to pantry" : "\(addedCount) items added to pantry"
        ToastManager.shared.show(label, style: .success)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Tracks an item saved via the full add/edit form.
    func trackManualAdd(_ item: PantryItem) {
        let entry = AddedPantryEntry(
            id: item.itemId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category
        )
        trackAddedItem(entry: entry, pantryItem: item)
    }

    func trackAddedItem(entry: AddedPantryEntry, pantryItem: PantryItem?) {
        addedItemNamesLower.insert(entry.name.lowercased())
        addedItems.append(entry)
        if let pantryItem {
            savedItemsCache[entry.id] = pantryItem
        }
    }

    private func clearCheckmarkAfterDelay(_ keyPath: ReferenceWritableKeyPath<AddItemHubViewModel, UUID?>) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            self?[keyPath: keyPath] = nil
        }
    }
}
