import SwiftUI

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Button(action: onToggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.completed ? Color.primaryGreen : Color.secondaryText)
                    .frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name), \(item.completed ? "completed" : "not completed")")
            .accessibilityHint("Double tap to toggle")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(AppFont.body)
                    .foregroundStyle(item.completed ? Color.secondaryText : Color.primaryText)
                    .strikethrough(item.completed)

                if item.quantity > 1 {
                    Text("Qty: \(item.quantity.formatted())")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()
        }
        .frame(minHeight: AppSpacing.minTouchTarget)
        .padding(AppSpacing.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .cardShadow()
    }
}
