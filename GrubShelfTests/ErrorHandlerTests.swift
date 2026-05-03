import Testing
import Foundation
@testable import GrubShelf

struct ErrorHandlerTests {
    @Test func networkErrorClassified() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let result = ErrorHandler.classify(error)
        if case .networkFailure = result {
            // pass
        } else {
            #expect(Bool(false), "Expected networkFailure, got \(result)")
        }
    }

    @Test func permissionErrorFromDescription() {
        let error = NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "403 forbidden"])
        let result = ErrorHandler.classify(error)
        if case .permissionDenied = result {
            // pass
        } else {
            #expect(Bool(false), "Expected permissionDenied, got \(result)")
        }
    }

    @Test func conflictErrorClassified() {
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "409 conflict detected"])
        let result = ErrorHandler.classify(error)
        if case .conflict = result {
            // pass
        } else {
            #expect(Bool(false), "Expected conflict, got \(result)")
        }
    }

    @Test func unknownErrorFallback() {
        let error = NSError(domain: "custom", code: 42, userInfo: [NSLocalizedDescriptionKey: "something weird"])
        let result = ErrorHandler.classify(error)
        if case .unknown = result {
            // pass
        } else {
            #expect(Bool(false), "Expected unknown, got \(result)")
        }
    }
}
