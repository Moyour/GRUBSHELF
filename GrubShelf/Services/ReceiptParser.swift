import Foundation

/// Parses raw OCR text lines into structured receipt data.
enum ReceiptParser {
    private static let totalPatterns = [
        "TOTAL", "GRAND TOTAL", "BALANCE DUE", "AMOUNT DUE", "TOTAL DUE",
        "SUBTOTAL", "FINAL TOTAL", "TOTAL PAYABLE"
    ]

    private static let discountPatterns = [
        "DISCOUNT", "COUPON", "SAVINGS", "VOUCHER", "PROMO",
        "MEMBER DISCOUNT", "LOYALTY", "REBATE", "REDUCTION"
    ]

    private static let priceRegex = try? NSRegularExpression(
        pattern: #"[\d,]+\.?\d*\s*[£$€]|[\£$€]\s*[\d,]+\.?\d*|[\d,]+\.\d{2}"#,
        options: []
    )

    private static let dateFormats: [DateFormatter] = {
        let formats = [
            "dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd",
            "MM/dd/yyyy", "dd.MM.yyyy", "dd MMM yyyy",
            "MMM dd, yyyy", "dd/MM/yy", "MM/dd/yy"
        ]
        return formats.map { fmt in
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_GB")
            return df
        }
    }()

    /// Parses OCR output into a structured ParsedReceipt.
    /// - Parameter lines: Tuples of (text, normalizedY) from ReceiptOCRService
    /// - Returns: ParsedReceipt with items, total, store, date
    static func parse(_ lines: [(text: String, y: CGFloat)]) -> ParsedReceipt {
        let sorted = lines.sorted { $0.y > $1.y } // Top to bottom (Vision Y increases downward)
        let rawLines = sorted.map(\.text)

        var storeName: String?
        var date: Date?
        var totalMinor: Int?
        var items: [ParsedReceiptItem] = []
        var itemLines: [(String, Int?)] = []
        var discountMinor: Int = 0

        for (index, line) in rawLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Store name: often in first 3–5 lines, no numbers
            if index < 5, storeName == nil, !containsPrice(trimmed), trimmed.count > 2, trimmed.count < 60 {
                if !totalPatterns.contains(where: { trimmed.uppercased().contains($0) }) {
                    storeName = trimmed
                }
            }

            // Date
            if date == nil, let parsed = parseDate(trimmed) {
                date = parsed
            }

            // Total
            let upper = trimmed.uppercased()
            if totalPatterns.contains(where: { upper.contains($0) }),
               let price = extractPriceMinor(trimmed) {
                totalMinor = price
            }

            // Discount lines: accumulate and skip from items
            if discountPatterns.contains(where: { upper.contains($0) }),
               let price = extractPriceMinor(trimmed) {
                discountMinor += price
                continue
            }

            // Item line: typically "Name  £X.XX" or "Name  Qty  £X.XX"
            if !totalPatterns.contains(where: { upper.contains($0) }),
               !["CASH", "CARD", "CHANGE", "THANK", "RECEIPT"].contains(where: { upper.contains($0) }) {
                let price = extractPriceMinor(trimmed)
                let namePart = trimPriceFromLine(trimmed)
                if namePart.count >= 2 {
                    itemLines.append((namePart, price))
                }
            }
        }

        // Subtract accumulated discounts from the total
        if discountMinor > 0, let total = totalMinor {
            totalMinor = max(total - discountMinor, 0)
        }

        // Build items from item lines
        for (name, priceMinor) in itemLines {
            let qty = extractQuantity(from: name)
            let cleanName = cleanItemName(name)
            if !cleanName.isEmpty {
                items.append(ParsedReceiptItem(name: cleanName, quantity: qty ?? 1, priceMinor: priceMinor))
            }
        }

        // Fallback: if no structured items, use non-total lines as raw items
        if items.isEmpty, !itemLines.isEmpty {
            items = itemLines.map { ParsedReceiptItem(name: $0.0, quantity: 1, priceMinor: $0.1) }
        }

        return ParsedReceipt(
            items: items,
            totalMinor: totalMinor,
            storeName: storeName,
            date: date ?? Date()
        )
    }

    private static func containsPrice(_ s: String) -> Bool {
        s.range(of: #"\d+\.\d{2}"#, options: .regularExpression) != nil
    }

    private static func extractPriceMinor(_ s: String) -> Int? {
        guard let regex = priceRegex else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: s, options: [], range: range) else { return nil }
        let matched = ns.substring(with: match.range)
        let digits = matched
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(digits) else { return nil }
        return Int(value * 100)
    }

    private static func trimPriceFromLine(_ line: String) -> String {
        guard let regex = priceRegex else { return line }
        let ns = line as NSString
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: ns.length))
        var result = line
        if let match = matches.last {
            result = ns.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    private static func extractQuantity(from name: String) -> Double? {
        // "2x Milk" or "2X Milk" — leading quantity with x/X
        if let leadRange = name.range(of: #"^\d+(?:\.\d+)?\s*[xX]\s+"#, options: .regularExpression) {
            let prefix = String(name[leadRange])
                .replacingOccurrences(of: "x", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return Double(prefix)
        }
        // "QTY 3" or "QTY: 3" — QTY prefix
        if let qtyRange = name.range(of: #"(?i)QTY\s*:?\s*(\d+(?:\.\d+)?)"#, options: .regularExpression) {
            let match = String(name[qtyRange])
            let digits = match.replacingOccurrences(of: #"(?i)QTY\s*:?\s*"#, with: "", options: .regularExpression)
            return Double(digits)
        }
        // "2 @ $3.99" — quantity-at-price
        if let atRange = name.range(of: #"(\d+(?:\.\d+)?)\s*@\s*"#, options: .regularExpression) {
            let match = String(name[atRange])
                .replacingOccurrences(of: "@", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Double(match)
        }
        // "Milk X2" or "Milk x2" — trailing uppercase/lowercase X
        if let xRange = name.range(of: #"[xX]\s*\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            let suffix = String(name[xRange])
                .replacingOccurrences(of: "X", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return Double(suffix)
        }
        // "Bread 2" — trailing bare number
        if let numRange = name.range(of: #"\s+\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            let suffix = String(name[numRange]).trimmingCharacters(in: .whitespaces)
            return Double(suffix)
        }
        return nil
    }

    private static func cleanItemName(_ name: String) -> String {
        var s = name
        // Remove leading "2x " or "2X "
        if let range = s.range(of: #"^\d+(?:\.\d+)?\s*[xX]\s+"#, options: .regularExpression) {
            s = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        // Remove "QTY 3" or "QTY: 3"
        if let range = s.range(of: #"(?i)QTY\s*:?\s*\d+(?:\.\d+)?"#, options: .regularExpression) {
            s = String(s[..<range.lowerBound] + s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        // Remove "N @ $price" (quantity-at-price)
        if let range = s.range(of: #"\d+(?:\.\d+)?\s*@\s*[£$€]?\d[\d,.]*"#, options: .regularExpression) {
            s = String(s[..<range.lowerBound] + s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        // Remove trailing "X2" or "x2"
        if let range = s.range(of: #"[xX]\s*\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        // Remove trailing bare number
        if let range = s.range(of: #"\s+\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func parseDate(_ s: String) -> Date? {
        for formatter in dateFormats {
            if let date = formatter.date(from: s) {
                return date
            }
        }
        return nil
    }
}
