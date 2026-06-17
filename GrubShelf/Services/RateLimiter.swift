import Foundation
import os

/// Client-side rate limiter using a sliding window of timestamps.
/// Persists timestamps to UserDefaults so limits survive app restarts.
actor RateLimiter {
    private let maxAttempts: Int
    private let windowDuration: TimeInterval
    private var timestamps: [Date] = []
    private let persistenceKey: String?
    private static let logger = Logger(subsystem: "com.grubshelf", category: "RateLimiter")

    init(maxAttempts: Int, window: TimeInterval, persistenceKey: String? = nil) {
        self.maxAttempts = maxAttempts
        self.windowDuration = window
        self.persistenceKey = persistenceKey

        if let key = persistenceKey,
           let stored = UserDefaults.standard.array(forKey: key) as? [Double] {
            let now = Date()
            let windowStart = now.addingTimeInterval(-window)
            self.timestamps = stored
                .map { Date(timeIntervalSince1970: $0) }
                .filter { $0 >= windowStart }
        }
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
        persist()
    }

    private func persist() {
        guard let key = persistenceKey else { return }
        let intervals = timestamps.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(intervals, forKey: key)
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
