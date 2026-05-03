import Foundation

/// Parses raw OCR text lines into structured receipt data.
enum ReceiptParser {
    private static let totalPatterns = [
        "TOTAL", "GRAND TOTAL", "BALANCE DUE", "AMOUNT DUE", "TOTAL DUE",
        "SUBTOTAL", "FINAL TOTAL", "TOTAL PAYABLE"
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
        // "Milk x2" or "Bread 2" at end
        if let xRange = name.range(of: #"x\s*\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            let suffix = String(name[xRange])
                .replacingOccurrences(of: "x", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Double(suffix)
        }
        if let numRange = name.range(of: #"\s+\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            let suffix = String(name[numRange]).trimmingCharacters(in: .whitespaces)
            return Double(suffix)
        }
        return nil
    }

    private static func cleanItemName(_ name: String) -> String {
        var s = name
        // Remove trailing "x N"
        if let range = s.range(of: #"x\s*\d+(?:\.\d+)?\s*$"#, options: .regularExpression) {
            s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
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
