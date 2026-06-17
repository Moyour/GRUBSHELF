import Testing
import Foundation
@testable import GrubShelf

struct NetworkRetryTests {
    @Test func cancellationErrorIsNotRetried() async {
        var attempts = 0
        do {
            _ = try await withRetry(maxAttempts: 3, initialDelay: .milliseconds(1)) {
                attempts += 1
                throw CancellationError()
            }
            #expect(Bool(false), "Expected CancellationError to propagate")
        } catch is CancellationError {
            #expect(attempts == 1)
        } catch {
            #expect(Bool(false), "Expected CancellationError, got \(error)")
        }
    }

    @Test func urlCancelledErrorIsNotRetried() async {
        var attempts = 0
        do {
            _ = try await withRetry(maxAttempts: 3, initialDelay: .milliseconds(1)) {
                attempts += 1
                throw URLError(.cancelled)
            }
            #expect(Bool(false), "Expected URLError.cancelled to propagate")
        } catch let error as URLError where error.code == .cancelled {
            #expect(attempts == 1)
        } catch {
            #expect(Bool(false), "Expected URLError.cancelled, got \(error)")
        }
    }

    @Test func transientErrorIsRetried() async {
        var attempts = 0
        do {
            _ = try await withRetry(maxAttempts: 3, initialDelay: .milliseconds(1)) {
                attempts += 1
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            }
            #expect(Bool(false), "Expected network error after retries")
        } catch {
            #expect(attempts == 3)
        }
    }
}
