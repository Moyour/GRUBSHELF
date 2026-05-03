import Foundation

/// Reads/writes the widget snapshot JSON in the App Group container (app + widget extension).
enum ShoppingListWidgetSnapshotStorage {
    private static let fileName = "shopping-widget-snapshot.json"

    static func load() -> ShoppingListWidgetSnapshot {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ShoppingListWidgetSnapshot.self, from: data)) ?? .empty
    }

    static func save(_ snapshot: ShoppingListWidgetSnapshot) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic])
    }

    private static func fileURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShoppingListWidgetAppGroup.identifier) else {
            return nil
        }
        return container.appendingPathComponent(fileName, isDirectory: false)
    }
}
