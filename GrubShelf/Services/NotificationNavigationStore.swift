import Foundation

/// Persists a notification tap destination until `ContentView` is ready (cold-start safe).
enum NotificationNavigationStore {
    private static let destinationKey = "notificationNavigation.pendingDestination"

    static func enqueue(_ destination: NotificationDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: destinationKey)
    }

    /// Returns and clears the pending destination, if any.
    static func consume() -> NotificationDestination? {
        guard let raw = UserDefaults.standard.string(forKey: destinationKey),
              let destination = NotificationDestination(rawValue: raw) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: destinationKey)
        return destination
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: destinationKey)
    }
}
