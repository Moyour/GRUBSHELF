import Foundation

extension String {
    /// Trims leading and trailing whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns `true` when the string is a structurally valid email address.
    var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}

extension ISO8601DateFormatter {
    /// Shared formatter — `ISO8601DateFormatter` is thread-safe, so a single instance is fine.
    static let shared = ISO8601DateFormatter()
}
