import Foundation

/// Helper utilities for shopping list item operations.
enum ShoppingListAddBehavior {
    /// Active pantry row matching a product the user is adding to a shopping list (name match).
    static func pantryMatch(in pantryItems: [PantryItem], name: String) -> PantryItem? {
        pantryItems.first { pantry in
            pantry.isApproved
                && !pantry.archived
                && GroceryCatalogSearchRanker.shoppingNamesMatch(pantry.name, name)
        }
    }

    static func inPantryInlineMessage(for pantry: PantryItem) -> String {
        "\(pantry.name) is in your pantry — \(pantry.quantity.formatted()) \(pantry.unit.abbreviation) left"
    }

    static func pantryMatchMessageWithTime(for pantry: PantryItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let timeAgo = formatter.localizedString(for: pantry.updatedAt, relativeTo: .now)
        return "\(pantry.name) is in your pantry — \(pantry.quantity.formatted()) \(pantry.unit.abbreviation) left (updated \(timeAgo))"
    }

    static func inPantrySuggestionSubtitle(for pantry: PantryItem) -> String {
        "\(pantry.quantity.formatted()) \(pantry.unit.abbreviation) left in pantry"
    }

    /// Applies a quantity delta. Returns false when the result would be below 1.
    static func applyQuantityChange(to item: inout ShoppingItem, delta: Int) -> Bool {
        let newQuantity = item.quantity + Double(delta)
        guard newQuantity >= 1 else { return false }
        item.quantity = newQuantity
        item.updatedAt = .now
        return true
    }
}
