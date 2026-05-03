import Foundation

extension Int {
    /// Converts minor currency units to a localized display string using device locale.
    /// Prefer `currencyFormatted(currencyCode:)` when user has selected a currency in budget settings.
    var currencyFormatted: String {
        currencyFormatted(currencyCode: nil)
    }

    /// Converts minor currency units to a display string for the given currency code.
    /// Example: 1550.currencyFormatted(currencyCode: "GBP") → "£15.50"
    /// - Parameter currencyCode: ISO 4217 code (e.g. "GBP", "USD", "EUR"). If nil, uses device locale.
    func currencyFormatted(currencyCode: String?) -> String {
        let value = Double(self) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let code = currencyCode, !code.isEmpty {
            formatter.currencyCode = code
            formatter.locale = Locale.currencyLocale(for: code)
        } else {
            formatter.locale = .current
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

extension Locale {
    /// Returns the currency symbol for the given ISO 4217 code (e.g. "GBP" → "£", "USD" → "$").
    static func currencySymbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = currencyLocale(for: currencyCode)
        return formatter.currencySymbol ?? "$"
    }

    /// Returns a locale that formats the given currency code correctly.
    static func currencyLocale(for currencyCode: String) -> Locale {
        let identifier: String
        switch currencyCode.uppercased() {
        case "GBP": identifier = "en_GB"
        case "USD": identifier = "en_US"
        case "EUR": identifier = "en_IE"
        case "NGN": identifier = "en_NG"
        case "CAD": identifier = "en_CA"
        case "AUD": identifier = "en_AU"
        default: identifier = "en_GB"
        }
        return Locale(identifier: identifier)
    }

    /// SF Symbol for currency-themed empty states. Uses the user’s budget currency when known; unknown codes default to **GBP** (sterling).
    static func currencyCircleSymbolName(for currencyCode: String) -> String {
        switch currencyCode.uppercased() {
        case "GBP": return "sterlingsign.circle"
        case "EUR": return "eurosign.circle"
        case "USD", "CAD", "AUD", "NGN": return "dollarsign.circle"
        case "JPY": return "yensign.circle"
        case "INR": return "indianrupeesign.circle"
        default: return "sterlingsign.circle"
        }
    }
}
