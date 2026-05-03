import Foundation

extension Notification.Name {
    /// Posted on the main thread after a widget toggle flush attempt so open Shop screens can reload.
    static let grubShelfShoppingWidgetToggleQueueFlushed = Notification.Name("com.grubshelf.shoppingWidgetToggleQueueFlushed")
}

/// Applies queued widget “mark done” actions against Supabase and refreshes the on-disk widget snapshot.
enum ShoppingListWidgetToggleQueueFlush {
    static func run(householdId: UUID) async {
        let pending = ShoppingListWidgetToggleQueue.loadPendingItemIds()
        guard !pending.isEmpty else { return }

        defer {
            Task { @MainActor in
                NotificationCenter.default.post(name: .grubShelfShoppingWidgetToggleQueueFlushed, object: nil)
            }
        }

        let shopRepo = SupabaseShoppingRepository()
        let listRepo = SupabaseShoppingListRepository()

        guard var items = try? await shopRepo.fetchAll(householdId: householdId) else { return }

        var remaining: [UUID] = []
        for id in pending {
            guard let item = items.first(where: { $0.itemId == id }) else { continue }
            if item.completed { continue }
            var updated = item
            updated.completed = true
            updated.updatedAt = .now
            do {
                let saved = try await shopRepo.update(updated)
                if let idx = items.firstIndex(where: { $0.itemId == id }) {
                    items[idx] = saved
                }
            } catch {
                remaining.append(id)
            }
        }

        ShoppingListWidgetToggleQueue.savePendingItemIds(remaining)

        guard let lists = try? await listRepo.fetchAll(householdId: householdId),
              let freshItems = try? await shopRepo.fetchAll(householdId: householdId) else { return }
        ShoppingListWidgetDataStore.shared.sync(lists: lists, items: freshItems)
    }
}
