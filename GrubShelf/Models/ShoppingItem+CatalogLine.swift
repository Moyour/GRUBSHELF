import Foundation

extension ShoppingItem {
    /// New shopping list row from a grocery catalog product (`catalog_item_id` set for quantity merge).
    static func newCatalogLine(
        from catalog: GroceryCatalogItem,
        householdId: UUID,
        listId: UUID?,
        createdBy: UUID,
        approvalStatus: ApprovalStatus
    ) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: catalog.name,
            quantity: 1,
            unit: catalog.defaultUnit,
            category: catalog.defaultCategory,
            completed: false,
            createdBy: createdBy,
            createdAt: .now,
            updatedAt: .now,
            approvalStatus: approvalStatus,
            catalogItemId: catalog.catalogItemId
        )
    }

    /// Free-text line (no catalog link). Used when the user submits typed text without picking a suggestion.
    static func newFreeTextLine(
        name: String,
        householdId: UUID,
        listId: UUID?,
        createdBy: UUID,
        approvalStatus: ApprovalStatus
    ) -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: name,
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            createdBy: createdBy,
            createdAt: .now,
            updatedAt: .now,
            approvalStatus: approvalStatus,
            catalogItemId: nil
        )
    }
}
