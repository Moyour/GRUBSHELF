import Foundation

/// Merges server shopping rows with in-flight local rows so realtime refresh does not drop
/// items that were just inserted but not yet returned by fetch.
enum ShoppingItemsMerge {
    static func merging(server: [ShoppingItem], preservingLocal local: [ShoppingItem]) -> [ShoppingItem] {
        let serverIds = Set(server.map(\.itemId))
        var merged = server
        for item in local where !serverIds.contains(item.itemId) {
            merged.append(item)
        }
        return merged.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
