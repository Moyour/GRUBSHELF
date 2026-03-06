import SwiftUI

struct PantryItemRow: View {
    let item: PantryItem
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(stateAccentColor)
                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                .background(stateAccentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconRadius))

            // Name + details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(
                        "\(item.quantity.formatted()) \(item.unit.abbreviation)",
                        systemImage: quantityIcon
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(item.state == .lowStock ? Color.warningAmber : Color.secondaryText)

                    if let expiry = item.expiryDate {
                        Text("·")
                            .foregroundStyle(Color.secondaryText)
                        Text(expiryText(expiry))
                            .font(AppFont.caption)
                            .foregroundStyle(expiryColor)
                    }
                }
            }

            Spacer()

            // Quick-adjust stepper
            if let onDecrement, let onIncrement {
                HStack(spacing: 0) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.secondaryText)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decrease quantity")

                    Text(item.quantity.formatted())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primaryText)
                        .frame(minWidth: 24)

                    Button(action: onIncrement) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.primaryGreen)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Increase quantity")
                }
            }

            // Status badge or category tag
            if let badge = statusBadge {
                Text(badge.label)
                    .font(AppFont.badgeLabel)
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.12))
                    .clipShape(Capsule())
            } else if onIncrement == nil {
                Text(item.category)
                    .font(AppFont.badgeLabel)
                    .foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appBackground)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Status Badge

    private struct StatusBadge {
        let label: String
        let color: Color
    }

    private var statusBadge: StatusBadge? {
        switch item.state {
        case .expired:
            return StatusBadge(label: "Expired", color: Color.errorRed)
        case .expiringSoon:
            return StatusBadge(label: "Expiring", color: Color.warningAmber)
        case .lowStock:
            return StatusBadge(label: "Low", color: Color.warningAmber)
        case .stale:
            return StatusBadge(label: "Review", color: Color.accentBlue)
        default:
            return nil
        }
    }

    private var stateAccentColor: Color {
        switch item.state {
        case .expired: Color.errorRed
        case .expiringSoon: Color.warningAmber
        case .lowStock: Color.warningAmber
        case .stale: Color.accentBlue
        default: Color.primaryGreen
        }
    }

    // MARK: - Quantity Icon

    private var quantityIcon: String {
        switch item.state {
        case .lowStock: "arrow.down.circle.fill"
        default: "scalemass"
        }
    }

    // MARK: - Expiry Helpers

    private var expiryColor: Color {
        switch item.state {
        case .expired: Color.errorRed
        case .expiringSoon: Color.warningAmber
        default: Color.secondaryText
        }
    }

    private func expiryText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Expired" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 7 { return "\(days)d left" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Category Icon

    private var categoryIcon: String {
        switch item.category.lowercased() {
        case "fruits": return "basket.fill"
        case "vegetables": return "leaf.fill"
        case "dairy": return "cup.and.saucer.fill"
        case "meat": return "fork.knife"
        case "seafood": return "fish.fill"
        case "grains": return "wheat.bundle.fill"
        case "snacks": return "popcorn.fill"
        case "beverages": return "mug.fill"
        case "frozen": return "snowflake"
        case "condiments": return "flask.fill"
        case "bakery": return "oven.fill"
        case "canned": return "shippingbox.fill"
        case "african staples": return "circle.hexagongrid.fill"
        case "african spices": return "flame.fill"
        case "other": return "bag.fill"
        default: return "cart.fill"
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [item.name, "\(item.quantity.formatted()) \(item.unit.displayName)", item.category]
        switch item.state {
        case .expired: parts.append("Expired")
        case .expiringSoon: parts.append("Expiring soon")
        case .lowStock: parts.append("Low stock")
        case .stale: parts.append("Needs review")
        default: break
        }
        return parts.joined(separator: ", ")
    }
}
