import Foundation

enum AppError: LocalizedError {
    case networkFailure(Error)
    case permissionDenied
    case validationError([String])
    case conflict
    case serverError(Int, String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "Network error. Your changes are saved locally and will sync when connected."
        case .permissionDenied:
            return "You do not have permission to perform this action."
        case .validationError(let errors):
            return errors.joined(separator: " ")
        case .conflict:
            return "A conflict was detected. The latest version has been applied."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
