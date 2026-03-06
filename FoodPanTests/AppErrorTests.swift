import Testing
import Foundation
@testable import FoodPan

struct AppErrorTests {
    @Test func networkFailureDescription() {
        let error = AppError.networkFailure(NSError(domain: "test", code: 0))
        #expect(error.errorDescription?.contains("Network") == true)
    }

    @Test func permissionDeniedDescription() {
        let error = AppError.permissionDenied
        #expect(error.errorDescription?.contains("permission") == true)
    }

    @Test func validationErrorJoinsMessages() {
        let error = AppError.validationError(["Name required.", "Quantity invalid."])
        #expect(error.errorDescription == "Name required. Quantity invalid.")
    }

    @Test func conflictDescription() {
        let error = AppError.conflict
        #expect(error.errorDescription?.contains("conflict") == true)
    }

    @Test func serverErrorIncludesCode() {
        let error = AppError.serverError(500, "Internal")
        #expect(error.errorDescription?.contains("500") == true)
    }

    @Test func unknownErrorDescription() {
        let error = AppError.unknown(NSError(domain: "test", code: 0))
        #expect(error.errorDescription?.contains("Something went wrong") == true)
    }
}
