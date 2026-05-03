import AppIntents
import Foundation

struct MarkShoppingListItemDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark done"
    static var description = IntentDescription("Marks a shopping list item as done in GrubShelf.")

    @Parameter(title: "Item ID")
    var itemId: String

    init() {}

    init(itemId: UUID) {
        self.itemId = itemId.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: itemId) else {
            return .result()
        }
        ShoppingListWidgetToggleQueue.enqueueMarkDoneAndRefreshSnapshot(itemId: uuid)
        return .result()
    }
}
