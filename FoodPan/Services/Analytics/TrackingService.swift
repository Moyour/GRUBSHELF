import Foundation
import OSLog

protocol TrackingService {
    func track(event: AnalyticsEvent, payload: TrackingPayload)
}

final class ConsoleTrackingService: TrackingService {
    private let logger = Logger(subsystem: "com.foodpan", category: "Analytics")

    func track(event: AnalyticsEvent, payload: TrackingPayload) {
        logger.info("[Analytics] \(event.rawValue) | user=\(payload.userId) household=\(payload.householdId) feature=\(payload.featureName)")
    }
}
