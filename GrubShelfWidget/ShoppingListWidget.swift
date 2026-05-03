import SwiftUI
import WidgetKit

struct ShoppingListWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ShoppingListWidgetSnapshot
}

struct ShoppingListWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingListWidgetEntry {
        ShoppingListWidgetEntry(
            date: .now,
            snapshot: ShoppingListWidgetSnapshot(
                updatedAt: .now,
                lists: [
                    ShoppingListWidgetListPayload(
                        listId: UUID(),
                        name: "Weekly shop",
                        pendingSamples: [
                            ShoppingListWidgetPendingLine(itemId: UUID(), title: "Milk"),
                            ShoppingListWidgetPendingLine(itemId: UUID(), title: "Bread"),
                            ShoppingListWidgetPendingLine(itemId: UUID(), title: "Eggs"),
                        ],
                        pendingCount: 3,
                        completedCount: 1
                    ),
                ],
                totalPendingCount: 3
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? placeholder(in: context).snapshot : ShoppingListWidgetSnapshotStorage.load()
        completion(ShoppingListWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListWidgetEntry>) -> Void) {
        let snapshot = ShoppingListWidgetSnapshotStorage.load()
        let entry = ShoppingListWidgetEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ShoppingListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ShoppingListWidgetKind.id, provider: ShoppingListWidgetProvider()) { entry in
            ShoppingListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GrubShelf")
        .description("Shopping list — see what’s left to buy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
