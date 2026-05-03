import Foundation

struct ErrorHandler {
    static func classify(_ error: Error) -> AppError {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            return .networkFailure(error)
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("403") || description.contains("permission") || description.contains("policy") {
            return .permissionDenied
        }

        if description.contains("409") || description.contains("conflict") {
            return .conflict
        }

        if let code = Int(description.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
           code >= 500 {
            return .serverError(code, description)
        }

        return .unknown(error)
    }
}
