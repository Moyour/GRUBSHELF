import Foundation

enum ShoppingListWidgetAppGroup {
    static let identifier = "group.com.grubshelf.GrubShelf"
}

enum ShoppingListWidgetKind {
    static let id = "ShoppingListWidget"
}

/// JSON snapshot written by the app and read by the widget extension (App Group).
struct ShoppingListWidgetSnapshot: Codable, Equatable, Sendable {
    var updatedAt: Date
    /// Active (non-transferred) lists: pinned first when set, otherwise newest list first (matches Shop).
    var lists: [ShoppingListWidgetListPayload]
    var totalPendingCount: Int

    static let empty = ShoppingListWidgetSnapshot(updatedAt: .distantPast, lists: [], totalPendingCount: 0)
}

/// One pending line shown on the widget; `itemId` is nil for legacy snapshots (display-only).
struct ShoppingListWidgetPendingLine: Codable, Equatable, Hashable, Sendable {
    let itemId: UUID?
    let title: String
}

struct ShoppingListWidgetListPayload: Equatable, Sendable, Identifiable {
    var id: UUID { listId }
    let listId: UUID
    let name: String
    /// Sample of pending items for display (full `pendingCount` may be larger). Lines without `itemId` cannot be toggled from the widget.
    let pendingSamples: [ShoppingListWidgetPendingLine]
    let pendingCount: Int
    let completedCount: Int

    /// Convenience for tests and “+N more” math (same ordering as `pendingSamples`).
    var pendingSampleTitles: [String] { pendingSamples.map(\.title) }

    enum CodingKeys: String, CodingKey {
        case listId
        case name
        case pendingSamples
        case pendingSampleTitles
        case pendingCount
        case completedCount
    }

    init(listId: UUID, name: String, pendingSamples: [ShoppingListWidgetPendingLine], pendingCount: Int, completedCount: Int) {
        self.listId = listId
        self.name = name
        self.pendingSamples = pendingSamples
        self.pendingCount = pendingCount
        self.completedCount = completedCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listId = try c.decode(UUID.self, forKey: .listId)
        name = try c.decode(String.self, forKey: .name)
        pendingCount = try c.decode(Int.self, forKey: .pendingCount)
        completedCount = try c.decode(Int.self, forKey: .completedCount)
        if let samples = try c.decodeIfPresent([ShoppingListWidgetPendingLine].self, forKey: .pendingSamples) {
            pendingSamples = samples
        } else if let titles = try c.decodeIfPresent([String].self, forKey: .pendingSampleTitles) {
            pendingSamples = titles.map { ShoppingListWidgetPendingLine(itemId: nil, title: $0) }
        } else {
            pendingSamples = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(listId, forKey: .listId)
        try c.encode(name, forKey: .name)
        try c.encode(pendingSamples, forKey: .pendingSamples)
        try c.encode(pendingCount, forKey: .pendingCount)
        try c.encode(completedCount, forKey: .completedCount)
    }
}

extension ShoppingListWidgetListPayload: Codable {}

extension ShoppingListWidgetListPayload {
    /// Applies a local “mark done” for widget UX when the item appears in `pendingSamples`.
    func removingPendingItem(itemId: UUID) -> ShoppingListWidgetListPayload {
        let newSamples = pendingSamples.filter { $0.itemId != itemId }
        guard newSamples.count != pendingSamples.count else { return self }
        return ShoppingListWidgetListPayload(
            listId: listId,
            name: name,
            pendingSamples: newSamples,
            pendingCount: max(0, pendingCount - 1),
            completedCount: completedCount + 1
        )
    }
}

extension ShoppingListWidgetSnapshot {
    func applyingMarkDone(itemId: UUID) -> ShoppingListWidgetSnapshot {
        var newLists: [ShoppingListWidgetListPayload] = []
        var didUpdate = false
        for list in lists {
            if list.pendingSamples.contains(where: { $0.itemId == itemId }) {
                newLists.append(list.removingPendingItem(itemId: itemId))
                didUpdate = true
            } else {
                newLists.append(list)
            }
        }
        guard didUpdate else { return self }
        return ShoppingListWidgetSnapshot(
            updatedAt: Date(),
            lists: newLists,
            totalPendingCount: max(0, totalPendingCount - 1)
        )
    }
}

/// App Group defaults — read when building the widget snapshot (main app).
enum ShoppingListWidgetPreferences {
    private static let pinnedListKey = "shoppingWidgetPinnedListId"

    static func pinnedListId() -> UUID? {
        guard let suite = UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier),
              let raw = suite.string(forKey: pinnedListKey) else { return nil }
        return UUID(uuidString: raw)
    }

    static func setPinnedList(_ listId: UUID) {
        UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier)?
            .set(listId.uuidString, forKey: pinnedListKey)
    }

    static func clearPinnedList() {
        UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier)?
            .removeObject(forKey: pinnedListKey)
    }

    /// Removes the pin when the list no longer exists or was transferred so the widget can fall back to the default order.
    static func clearStalePinIfNeeded(activeNonTransferredListIds: Set<UUID>) {
        if let pin = pinnedListId(), !activeNonTransferredListIds.contains(pin) {
            clearPinnedList()
        }
    }
}
