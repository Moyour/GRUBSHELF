import SwiftUI

/// Legacy wrapper — production flows use [`TransferFlowSheet`] (audit + transfer on one screen).
struct ShoppingAuditView: View {
    let transferableItems: [ShoppingItem]
    let pantryItems: [PantryItem]
    let householdId: UUID
    let userId: UUID
    let listId: UUID?
    var currencyCode: String = "GBP"

    init(
        transferableItems: [ShoppingItem],
        pantryItems: [PantryItem],
        householdId: UUID,
        userId: UUID,
        listId: UUID?,
        currencyCode: String = "GBP"
    ) {
        self.transferableItems = transferableItems
        self.pantryItems = pantryItems
        self.householdId = householdId
        self.userId = userId
        self.listId = listId
        self.currencyCode = currencyCode
    }

    var body: some View {
        TransferFlowSheet(
            transferableItems: transferableItems,
            pantryItems: pantryItems,
            householdId: householdId,
            userId: userId,
            listId: listId,
            currencyCode: currencyCode
        )
    }
}
