import Foundation

struct ErrorHandler {
    static func classify(_ error: Error) -> AppError {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            return .networkFailure(error)
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("network")
            || description.contains("offline")
            || description.contains("timed out")
            || description.contains("could not connect")
            || description.contains("internet connection") {
            return .networkFailure(error)
        }

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

    static func userMessage(for error: Error, action: String) -> String {
        switch classify(error) {
        case .networkFailure:
            return "Couldn't \(action). You're offline right now — reconnect and try again."
        case .permissionDenied:
            return "Couldn't \(action). Your role doesn't allow this action."
        case .conflict:
            return "Couldn't \(action). The data changed on another device — refresh and try again."
        case .serverError:
            return "Couldn't \(action). Server is temporarily unavailable — try again shortly."
        case .validationError(let errors):
            let details = errors.joined(separator: " ")
            return details.isEmpty ? "Couldn't \(action). Check the entered details and try again." : details
        case .unknown:
            return "Couldn't \(action). Please try again."
        }
    }
}
