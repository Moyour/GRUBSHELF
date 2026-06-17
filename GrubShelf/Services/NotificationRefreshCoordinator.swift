import BackgroundTasks
import Foundation

/// Registers and runs background refresh so notifications stay scheduled without opening the app.
enum NotificationRefreshCoordinator {
    static let taskIdentifier = "com.grubshelf.notifications.refresh"

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundRefresh(refreshTask)
        }
    }

    static func scheduleBackgroundRefresh(preferredHour: Int = EngagementStore.shared.preferredNotificationHour()) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextRefreshDate(preferredHour: preferredHour)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func nextRefreshDate(preferredHour: Int, referenceDate: Date = .now, calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.hour = max(0, preferredHour - 1)
        components.minute = 0
        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? referenceDate.addingTimeInterval(60 * 60)
    }

    private static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            let success = await refreshScheduledNotifications()
            task.setTaskCompleted(success: success)
        }
    }

    static func refreshScheduledNotifications() async -> Bool {
        guard let context = NotificationContextStore.load() else { return false }
        await NotificationDataLoader.scheduleNotifications(
            householdId: context.householdId,
            userId: context.userId
        )
        return true
    }
}
