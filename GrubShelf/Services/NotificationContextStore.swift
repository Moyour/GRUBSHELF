import Foundation

/// Persists the signed-in household context so background refresh can reschedule notifications.
enum NotificationContextStore {
    private static let householdKey = "notificationContext.householdId"
    private static let userKey = "notificationContext.userId"

    static func save(householdId: UUID, userId: UUID) {
        UserDefaults.standard.set(householdId.uuidString, forKey: householdKey)
        UserDefaults.standard.set(userId.uuidString, forKey: userKey)
    }

    static func load() -> (householdId: UUID, userId: UUID)? {
        guard
            let householdRaw = UserDefaults.standard.string(forKey: householdKey),
            let userRaw = UserDefaults.standard.string(forKey: userKey),
            let householdId = UUID(uuidString: householdRaw),
            let userId = UUID(uuidString: userRaw)
        else { return nil }
        return (householdId, userId)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: householdKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}
