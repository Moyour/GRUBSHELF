import Foundation
import WidgetKit

/// Persists shopping list snapshot for the home-screen widget (main app only).
final class ShoppingListWidgetDataStore {
    static let shared = ShoppingListWidgetDataStore()

    private init() {}

    func sync(lists: [ShoppingList], items: [ShoppingItem]) {
        let snapshot = ShoppingListWidgetSnapshotBuilder.build(lists: lists, items: items)
        ShoppingListWidgetSnapshotStorage.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: ShoppingListWidgetKind.id)
    }

    func clear() {
        ShoppingListWidgetSnapshotStorage.save(.empty)
        WidgetCenter.shared.reloadTimelines(ofKind: ShoppingListWidgetKind.id)
    }
}
