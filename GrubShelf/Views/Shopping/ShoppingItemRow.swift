import SwiftUI
import UIKit

struct ShoppingItemRow: View {
    let item: ShoppingItem
    var canToggle: Bool = true
    var isAdjustingQuantity: Bool = false
    var pantryQuantityHint: String?
    let onToggle: () -> Void
    var onIncrementQuantity: (() -> Void)?
    var onDecrementQuantity: (() -> Void)?

    private var showsQuantityStepper: Bool {
        onIncrementQuantity != nil && onDecrementQuantity != nil
    }

    private var showsQtyLabel: Bool {
        !showsQuantityStepper && item.quantity > 1
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(BrandSymbolFont.symbol(24))
                    .foregroundStyle(item.completed ? .gsSuccess : .gsTextSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.45)
            .accessibilityLabel("\(item.name), \(item.completed ? "completed" : "not completed")")
            .accessibilityHint(canToggle ? "Double tap to toggle" : "Awaiting admin approval")

            Text(ItemIconMapper.emoji(for: item.name, category: item.category ?? ""))
                .font(BrandFont.regular(20))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(item.name)
                    .font(item.completed ? BrandFont.regular(17) : BrandFont.semiBold(17))
                    .foregroundStyle(item.completed ? .gsTextSecondary : .gsTextPrimary)
                    .strikethrough(item.completed)
                    .multilineTextAlignment(.leading)
                    .lineLimit(showsQtyLabel ? 1 : 2)
                    .truncationMode(.tail)

                if showsQtyLabel {
                    Text("Qty \(item.quantity.formatted())")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }

                if let hint = pantryQuantityHint {
                    HStack(spacing: AppSpacing.denseSpacing) {
                        Image(systemName: "archivebox.fill")
                            .font(BrandSymbolFont.symbol(11))
                        Text(hint)
                    }
                    .font(BrandFont.semiBold(13))
                    .foregroundStyle(.gsWarning)
                    .padding(.horizontal, AppSpacing.smallSpacing)
                    .padding(.vertical, AppSpacing.microGap)
                    .background(Color.gsWarningSurface)
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if showsQuantityStepper {
                quantityStepper
                    .layoutPriority(2)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if item.approvalStatus != .approved {
                ApprovalStatusBadge(status: item.approvalStatus)
                    .layoutPriority(2)
                    .fixedSize(horizontal: true, vertical: true)
            } else if item.completed {
                StatusBadgeView(status: .done)
                    .layoutPriority(2)
                    .fixedSize(horizontal: true, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 64)
        .padding(.vertical, AppSpacing.mediumSpacing)
        .padding(.horizontal, AppSpacing.cardPadding)
        .dashboardCardSurface()
    }

    private var quantityStepper: some View {
        HStack(spacing: AppSpacing.compactGap) {
            Button(action: { onDecrementQuantity?() }) {
                Image(systemName: "minus.circle.fill")
                    .font(BrandSymbolFont.symbol(26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gsTextSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdjustingQuantity)
            .accessibilityLabel("Decrease quantity")

            Text(item.quantity.formatted(.number.precision(.fractionLength(0...1))))
                .font(BrandFont.semiBold(16))
                .foregroundStyle(.gsTextPrimary)
                .frame(minWidth: 24)

            Button(action: { onIncrementQuantity?() }) {
                Image(systemName: "plus.circle.fill")
                    .font(BrandSymbolFont.symbol(26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gsBrandPrimary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdjustingQuantity)
            .accessibilityLabel("Increase quantity")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quantity \(item.quantity.formatted())")
    }
}
