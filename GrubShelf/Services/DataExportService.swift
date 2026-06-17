import Foundation

enum ExportFormat: String {
    case json, csv
}

struct DataExportService {

    // MARK: - Unified export-to-file

    /// Fetches all household data, writes to a temp file, and returns the URL.
    static func exportToFile(format: ExportFormat, householdId: UUID) async throws -> URL {
        let pantryRepo = SupabasePantryRepository()
        let shoppingRepo = SupabaseShoppingRepository()
        let shoppingListRepo = SupabaseShoppingListRepository()
        let wasteRepo = SupabaseWasteEventRepository()

        async let pantryFetch = pantryRepo.fetchAll(householdId: householdId)
        async let shoppingFetch = shoppingRepo.fetchAll(householdId: householdId)
        async let listsFetch = shoppingListRepo.fetchAll(householdId: householdId)
        async let wasteFetch = wasteRepo.fetchByDateRange(householdId: householdId, start: .distantPast, end: .now)

        let (pantryItems, shoppingItems, shoppingLists, wasteEvents) = try await (pantryFetch, shoppingFetch, listsFetch, wasteFetch)
        let tempDir = FileManager.default.temporaryDirectory

        switch format {
        case .json:
            let data = try exportJSON(
                pantryItems: pantryItems,
                shoppingLists: shoppingLists,
                shoppingItems: shoppingItems,
                wasteEvents: wasteEvents
            )
            let fileURL = tempDir.appendingPathComponent("Grub-Shelf-Export.json")
            try data.write(to: fileURL)
            return fileURL
        case .csv:
            let csv = exportCSV(
                pantryItems: pantryItems,
                shoppingItems: shoppingItems,
                wasteEvents: wasteEvents
            )
            let fileURL = tempDir.appendingPathComponent("Grub-Shelf-Export.csv")
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }

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
            let expiry = item.expiryDate.map { ISO8601DateFormatter.shared.string(from: $0) } ?? ""
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
            let date = ISO8601DateFormatter.shared.string(from: event.date)
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
