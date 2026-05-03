import Foundation

struct DataExportService {

    // MARK: - Export All Data as JSON

    static func exportJSON(
        pantryItems: [PantryItem],
        shoppingLists: [ShoppingList],
        shoppingItems: [ShoppingItem],
        wasteEvents: [WasteEvent]
    ) throws -> Data {
        let payload = ExportPayload(
            exportedAt: Date.now,
            pantryItems: pantryItems,
            shoppingLists: shoppingLists,
            shoppingItems: shoppingItems,
            wasteEvents: wasteEvents
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    // MARK: - Export as CSV

    static func exportCSV(
        pantryItems: [PantryItem],
        shoppingItems: [ShoppingItem],
        wasteEvents: [WasteEvent]
    ) -> String {
        var csv = ""

        // Pantry Items
        csv += "--- PANTRY ITEMS ---\n"
        csv += "Name,Quantity,Unit,Category,Expiry Date,Low Stock Threshold,Archived\n"
        for item in pantryItems {
            let expiry = item.expiryDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            csv += "\(escapeCSV(item.name)),\(item.quantity),\(item.unit.abbreviation),\(escapeCSV(item.category)),\(expiry),\(item.lowStockThreshold),\(item.archived)\n"
        }

        csv += "\n--- SHOPPING ITEMS ---\n"
        csv += "Name,Quantity,Unit,Category,Completed,Transferred\n"
        for item in shoppingItems {
            let unit = item.unit?.abbreviation ?? ""
            let category = item.category ?? ""
            csv += "\(escapeCSV(item.name)),\(item.quantity),\(unit),\(escapeCSV(category)),\(item.completed),\(item.transferred)\n"
        }

        csv += "\n--- WASTE EVENTS ---\n"
        csv += "Item Name,Date,Estimated Cost,Source\n"
        for event in wasteEvents {
            let date = ISO8601DateFormatter().string(from: event.date)
            let cost = event.estimatedCostMinor.map { String(format: "%.2f", Double($0) / 100.0) } ?? ""
            csv += "\(escapeCSV(event.itemName)),\(date),\(cost),\(event.source)\n"
        }

        return csv
    }

    private static func escapeCSV(_ value: String) -> String {
        var escaped = value

        // CSV formula injection prevention: prefix dangerous leading characters with a single quote
        let dangerousPrefixes: [Character] = ["=", "+", "-", "@"]
        if let first = escaped.first, dangerousPrefixes.contains(first) || escaped.hasPrefix("\t") || escaped.hasPrefix("\r") {
            escaped = "'" + escaped
        }

        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return escaped
    }
}

// MARK: - Export Payload

private struct ExportPayload: Encodable {
    let exportedAt: Date
    let pantryItems: [PantryItem]
    let shoppingLists: [ShoppingList]
    let shoppingItems: [ShoppingItem]
    let wasteEvents: [WasteEvent]
}
