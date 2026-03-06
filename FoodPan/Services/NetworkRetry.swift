import Foundation
import os

private let logger = Logger(subsystem: "com.foodpan", category: "Network")

/// Retries a throwing async operation with exponential backoff.
/// Only retries on transient network errors; permanent errors (permission, validation) rethrow immediately.
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: Duration = .milliseconds(500),
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            let classified = ErrorHandler.classify(error)

            // Don't retry non-transient errors
            switch classified {
            case .permissionDenied, .validationError, .conflict:
                throw error
            case .networkFailure, .serverError, .unknown:
                break
            }

            if attempt < maxAttempts {
                let delay = initialDelay * Int(pow(2.0, Double(attempt - 1)))
                logger.info("Retry \(attempt)/\(maxAttempts) after \(error.localizedDescription)")
                try? await Task.sleep(for: delay)
            }
        }
    }

    throw lastError!
}
