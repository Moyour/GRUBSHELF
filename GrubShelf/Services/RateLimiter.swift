import Foundation
import os

/// Client-side rate limiter using a sliding window of timestamps.
actor RateLimiter {
    private let maxAttempts: Int
    private let windowDuration: TimeInterval
    private var timestamps: [Date] = []
    private static let logger = Logger(subsystem: "com.grubshelf", category: "RateLimiter")

    init(maxAttempts: Int, window: TimeInterval) {
        self.maxAttempts = maxAttempts
        self.windowDuration = window
    }

    /// Call before each protected operation. Throws `RateLimitError` if the limit is exceeded.
    func attempt() throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowDuration)

        // Remove expired timestamps
        timestamps.removeAll { $0 < windowStart }

        if timestamps.count >= maxAttempts {
            let oldestInWindow = timestamps.first ?? now
            let resetInterval = oldestInWindow.addingTimeInterval(windowDuration).timeIntervalSince(now)
            let secondsRemaining = max(1, Int(ceil(resetInterval)))
            Self.logger.warning("Rate limit exceeded: \(self.timestamps.count)/\(self.maxAttempts) in window")
            throw RateLimitError.exceeded(retryAfterSeconds: secondsRemaining)
        }

        timestamps.append(now)
    }
}

enum RateLimitError: LocalizedError {
    case exceeded(retryAfterSeconds: Int)

    var errorDescription: String? {
        switch self {
        case .exceeded(let seconds):
            return "Too many attempts. Please wait \(seconds) seconds."
        }
    }
}
