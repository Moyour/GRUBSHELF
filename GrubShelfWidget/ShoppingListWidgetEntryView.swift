import SwiftUI
import WidgetKit

/// Widget target does not link app `BrandPalette`; keep hex values in sync with `BrandColors` / `BrandPalette.Teal` and `gsTextOnBrand`.
private enum ShoppingListWidgetChrome {
    /// `BrandPalette.Teal.s900` (#04342C)
    static let background = Color(
        .sRGB,
        red: 4.0 / 255.0,
        green: 52.0 / 255.0,
        blue: 44.0 / 255.0,
        opacity: 1
    )
    /// `BrandPalette.Teal.s400` (#2AB88A)
    static let accentTint = Color(
        .sRGB,
        red: 42.0 / 255.0,
        green: 184.0 / 255.0,
        blue: 138.0 / 255.0,
        opacity: 1
    )
    /// Matches `Color.gsTextOnBrand` (light label on fixed dark brand fills).
    static let onDark = Color(
        .sRGB,
        red: 0.949,
        green: 0.941,
        blue: 0.918,
        opacity: 1
    )
}

struct ShoppingListWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ShoppingListWidgetProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallContent
            case .systemMedium:
                mediumContent
            case .systemLarge:
                largeContent
            default:
                mediumContent
            }
        }
        .containerBackground(for: .widget) {
            ShoppingListWidgetChrome.background
        }
    }

    // MARK: - Small

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "cart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShoppingListWidgetChrome.accentTint)
                Text("Shop")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.9))
            }
            if entry.snapshot.totalPendingCount == 0 {
                Text("All caught up")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark)
                    .minimumScaleFactor(0.85)
                Text("Open GrubShelf")
                    .font(.caption2)
                    .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.55))
            } else {
                Text("\(entry.snapshot.totalPendingCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark)
                Text("to buy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    // MARK: - Medium

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            if let first = entry.snapshot.lists.first {
                Text(first.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark)
                    .lineLimit(1)
                itemLines(for: first, maxLines: 4)
                if first.pendingCount > first.pendingSamples.count {
                    Text("+\(first.pendingCount - first.pendingSamples.count) more")
                        .font(.caption2)
                        .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.5))
                }
            } else {
                emptyCopy
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    // MARK: - Large

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            if entry.snapshot.lists.isEmpty {
                emptyCopy
            } else {
                ForEach(entry.snapshot.lists) { list in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(list.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ShoppingListWidgetChrome.onDark)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if list.pendingCount > 0 {
                                Text("\(list.pendingCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ShoppingListWidgetChrome.accentTint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ShoppingListWidgetChrome.onDark.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        itemLines(for: list, maxLines: 3)
                        listOverflowFooter(list: list, maxLines: 3)
                    }
                    .padding(.bottom, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var headerRow: some View {
        HStack {
            Image(systemName: "cart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ShoppingListWidgetChrome.accentTint)
            Text("GrubShelf")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.85))
            Spacer(minLength: 0)
            if entry.snapshot.totalPendingCount > 0 {
                Text("\(entry.snapshot.totalPendingCount) left")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.55))
            }
        }
    }

    private var emptyCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No lists yet")
                .font(.body.weight(.semibold))
                .foregroundStyle(ShoppingListWidgetChrome.onDark)
            Text("Open the app and pull to refresh Shop, or add a list to sync here.")
                .font(.caption)
                .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func listOverflowFooter(list: ShoppingListWidgetListPayload, maxLines: Int) -> some View {
        let shown = min(maxLines, list.pendingSamples.count)
        if list.pendingCount > shown {
            Text("+\(list.pendingCount - shown) more in this list")
                .font(.caption2)
                .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.45))
        }
    }

    @ViewBuilder
    private func itemLines(for list: ShoppingListWidgetListPayload, maxLines: Int) -> some View {
        let lines = Array(list.pendingSamples.prefix(maxLines))
        if lines.isEmpty {
            Text(list.pendingCount == 0 ? "Nothing pending" : "Open app to sync items")
                .font(.caption)
                .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.5))
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    pendingLineRow(line)
                }
            }
        }
    }

    @ViewBuilder
    private func pendingLineRow(_ line: ShoppingListWidgetPendingLine) -> some View {
        if let itemId = line.itemId {
            Button(intent: MarkShoppingListItemDoneIntent(itemId: itemId)) {
                pendingLineLabel(title: line.title, quantity: line.quantity, showsCheckbox: true)
            }
            .buttonStyle(.plain)
        } else {
            pendingLineLabel(title: line.title, quantity: line.quantity, showsCheckbox: false)
        }
    }

    private func pendingLineLabel(title: String, quantity: Double?, showsCheckbox: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if showsCheckbox {
                Image(systemName: "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShoppingListWidgetChrome.accentTint)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .fill(ShoppingListWidgetChrome.accentTint.opacity(0.85))
                    .frame(width: 5, height: 5)
                    .frame(width: 18, height: 18, alignment: .center)
            }
            Text(formattedTitle(title: title, quantity: quantity))
                .font(.caption)
                .foregroundStyle(ShoppingListWidgetChrome.onDark.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func formattedTitle(title: String, quantity: Double?) -> String {
        guard let qty = quantity, qty > 1 else { return title }
        let formatted = qty.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", qty)  // "2" not "2.0"
            : String(format: "%.1f", qty)  // "2.5"
        return "\(title) ×\(formatted)"
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    ShoppingListWidget()
} timeline: {
    ShoppingListWidgetEntry(date: .now, snapshot: .empty)
    ShoppingListWidgetEntry(
        date: .now,
        snapshot: ShoppingListWidgetSnapshot(
            updatedAt: .now,
            lists: [
                ShoppingListWidgetListPayload(
                    listId: UUID(),
                    name: "Saturday run",
                    pendingSamples: [
                        ShoppingListWidgetPendingLine(itemId: UUID(), title: "Oats", quantity: 1),
                        ShoppingListWidgetPendingLine(itemId: UUID(), title: "Bananas", quantity: 2),
                        ShoppingListWidgetPendingLine(itemId: UUID(), title: "Yogurt", quantity: 3.5),
                    ],
                    pendingCount: 5,
                    completedCount: 0
                ),
            ],
            totalPendingCount: 5
        )
    )
}
#endif
