import Foundation
import WidgetKit

/// Persists shopping-item IDs the user marked done from the widget; the main app flushes to Supabase.
enum ShoppingListWidgetToggleQueue {
    private static let fileName = "shopping-widget-toggle-queue.json"

    static func loadPendingItemIds() -> [UUID] {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
    }

    static func savePendingItemIds(_ ids: [UUID]) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(ids) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if ids.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else {
            try? data.write(to: url, options: [.atomic])
        }
    }

    static func clear() {
        savePendingItemIds([])
    }

    /// Enqueue server sync, apply optimistic snapshot update, reload widget timelines.
    static func enqueueMarkDoneAndRefreshSnapshot(itemId: UUID) {
        var pending = loadPendingItemIds()
        if !pending.contains(itemId) { pending.append(itemId) }
        savePendingItemIds(pending)

        var snapshot = ShoppingListWidgetSnapshotStorage.load()
        snapshot = snapshot.applyingMarkDone(itemId: itemId)
        ShoppingListWidgetSnapshotStorage.save(snapshot)

        WidgetCenter.shared.reloadTimelines(ofKind: ShoppingListWidgetKind.id)
    }

    private static func fileURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShoppingListWidgetAppGroup.identifier) else {
            return nil
        }
        return container.appendingPathComponent(fileName, isDirectory: false)
    }
}
