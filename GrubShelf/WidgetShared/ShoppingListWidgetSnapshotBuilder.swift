import Foundation

enum ShoppingListWidgetSnapshotBuilder {
    /// Maximum pending titles stored per list (keeps widget payload small).
    static let maxTitlesPerList = 12
    /// Lists included in snapshot (beyond the first, used for large widget).
    static let maxLists = 4

    /// Active lists for widget and Home preview: pinned list first (if still active), then newest list first — same order as Shop (`created_at` descending from fetch).
    static func orderedActiveLists(lists: [ShoppingList]) -> [ShoppingList] {
        let active = lists.filter { !$0.transferred }
        let pin = ShoppingListWidgetPreferences.pinnedListId()

        return active.sorted { lhs, rhs in
            if let pin {
                let lPinned = lhs.listId == pin
                let rPinned = rhs.listId == pin
                if lPinned != rPinned { return lPinned && !rPinned }
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.listId.uuidString > rhs.listId.uuidString
        }
    }

    static func build(lists: [ShoppingList], items: [ShoppingItem]) -> ShoppingListWidgetSnapshot {
        let activeIds = Set(lists.filter { !$0.transferred }.map(\.listId))
        ShoppingListWidgetPreferences.clearStalePinIfNeeded(activeNonTransferredListIds: activeIds)

        let activeLists = orderedActiveLists(lists: lists)
        let itemsByList = Dictionary(grouping: items.compactMap { item -> (UUID, ShoppingItem)? in
            guard let listId = item.listId else { return nil }
            return (listId, item)
        }) { $0.0 }.mapValues { $0.map(\.1) }

        var payloads: [ShoppingListWidgetListPayload] = []
        var totalPending = 0

        for list in activeLists.prefix(maxLists) {
            let listItems = itemsByList[list.listId] ?? []
            let pending = listItems.filter { !$0.completed }
            let completed = listItems.filter(\.completed)
            totalPending += pending.count

            let sampleLines: [ShoppingListWidgetPendingLine] = pending
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(maxTitlesPerList)
                .map { ShoppingListWidgetPendingLine(itemId: $0.itemId, title: $0.name, quantity: $0.quantity) }

            payloads.append(
                ShoppingListWidgetListPayload(
                    listId: list.listId,
                    name: list.name,
                    pendingSamples: sampleLines,
                    pendingCount: pending.count,
                    completedCount: completed.count
                )
            )
        }

        return ShoppingListWidgetSnapshot(
            updatedAt: .now,
            lists: payloads,
            totalPendingCount: totalPending
        )
    }
}
