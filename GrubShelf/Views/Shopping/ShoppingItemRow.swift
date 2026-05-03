import SwiftUI

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Button(action: onToggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(BrandSymbolFont.symbol(24))
                    .foregroundStyle(item.completed ? .gsSuccess : .gsTextSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name), \(item.completed ? "completed" : "not completed")")
            .accessibilityHint("Double tap to toggle")

            Text(ItemIconMapper.emoji(for: item.name, category: item.category ?? ""))
                .font(BrandFont.regular(20))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(item.name)
                    .font(item.completed ? BrandFont.regular(17) : BrandFont.semiBold(17))
                    .foregroundStyle(item.completed ? .gsTextSecondary : .gsTextPrimary)
                    .strikethrough(item.completed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .truncationMode(.tail)

                if item.quantity > 1 {
                    Text("Qty \(item.quantity.formatted())")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if item.completed {
                StatusBadgeView(status: .done)
                    .fixedSize(horizontal: true, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 64)
        .padding(.vertical, AppSpacing.mediumSpacing)
        .padding(.horizontal, AppSpacing.cardPadding)
        .dashboardCardSurface()
    }
}
