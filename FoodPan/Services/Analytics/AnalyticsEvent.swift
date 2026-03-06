import Foundation

enum AnalyticsEvent: String {
    case itemAdded = "item_added"
    case itemDeleted = "item_deleted"
    case shoppingTransferred = "shopping_transferred"
    case expiryNotificationOpened = "expiry_notification_opened"
    case duplicatePrevented = "duplicate_prevented"
    case costEntered = "cost_entered"
}

struct TrackingPayload {
    let userId: String
    let householdId: String
    let timestamp: Date
    let featureName: String
    var metadata: [String: String] = [:]
}
