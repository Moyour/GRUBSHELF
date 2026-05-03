import SwiftUI

struct PantryItemRow: View {
    let item: PantryItem
    var confidence: Double = 1.0
    /// Tapping the name / details region (not the stepper) — avoids competing with +/- `Button`s in a `List` row.
    var onTapEdit: (() -> Void)?
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?
    /// When true, quantity in the stepper animates with numeric content transition (e.g. on Home).
    var animateQuantityChanges: Bool = false
    private static let photoStorage: PantryPhotoStorage = SupabasePantryPhotoStorage()

    var body: some View {
        /// `denseSpacing` everywhere between emoji, text column, and stepper so rhythm matches name/meta/badge stacks.
        HStack(alignment: .top, spacing: AppSpacing.denseSpacing) {
            Group {
                HStack(alignment: .top, spacing: AppSpacing.denseSpacing) {
                    if let photoURL = pantryPhotoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                fallbackIcon
                            }
                        }
                        .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius))
                    } else {
                        fallbackIcon
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                        Text(item.name)
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.88)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: AppSpacing.denseSpacing) {
                            Label {
                                quantityLabelText
                            } icon: {
                                Image(systemName: quantityIcon)
                            }
                            .font(BrandFont.regular(14))
                            .foregroundStyle(item.state == .lowStock ? .gsWarning : .gsTextSecondary)

                            if let expiry = item.expiryDate {
                                Text("·")
                                    .foregroundStyle(.gsTextSecondary)
                                Text(expiryText(expiry))
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(expiryColor)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(OptionalTapGestureModifier(action: onTapEdit))

            VStack(alignment: .trailing, spacing: AppSpacing.denseSpacing) {
                if let badgeStatus = badgeStatus {
                    StatusBadgeView(status: badgeStatus)
                        .fixedSize(horizontal: true, vertical: true)
                }

                if let onDecrement, let onIncrement {
                    HStack(spacing: 0) {
                        Button(action: onDecrement) {
                            Image(systemName: "minus.circle.fill")
                                .font(BrandSymbolFont.symbol(20))
                                .foregroundStyle(.gsTextSecondary)
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Decrease quantity")

                        Text(item.quantity.formatted())
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(.gsTextPrimary)
                            .frame(minWidth: AppSpacing.quantityColumnMinWidth)
                            .contentTransition(.numericText())
                            .animation(animateQuantityChanges ? .easeOut(duration: 0.2) : nil, value: item.quantity)

                        Button(action: onIncrement) {
                            Image(systemName: "plus.circle.fill")
                                .font(BrandSymbolFont.symbol(20))
                                .foregroundStyle(.gsBrandPrimary)
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase quantity")
                    }
                }

                if badgeStatus == nil, onIncrement == nil {
                    Text(item.category)
                        .font(BrandFont.semiBold(13))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                        .padding(.horizontal, AppSpacing.smallSpacing)
                        .padding(.vertical, AppSpacing.compactGap)
                        .background(.gsBackground)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(minHeight: badgeStatus == nil ? 72 : 88)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .dashboardCardSurfaceElevated()
        .opacity(confidence < 0.7 ? max(0.55, confidence) : 1.0)
    }

    // MARK: - Quantity label (inline)

    @ViewBuilder
    private var quantityLabelText: some View {
        Text("\(item.quantity.formatted()) \(item.unit.abbreviation)")
            .contentTransition(.numericText())
            .animation(animateQuantityChanges ? .easeOut(duration: 0.2) : nil, value: item.quantity)
    }

    // MARK: - Status Badge

    private var badgeStatus: StatusBadgeView.Status? {
        switch item.state {
        case .expired:      return .expired
        case .expiringSoon: return .expiring
        case .lowStock:     return .low
        case .stale:        return .review
        default:
            if confidence < 0.3 { return .gone }
            if confidence < 0.7 { return .check }
            return nil
        }
    }

    private var stateAccentColor: Color {
        switch item.state {
        case .expired: .gsDanger
        case .expiringSoon: .gsWarning
        case .lowStock: .gsWarning
        case .stale: .gsBrandPrimary
        default: .gsBrandPrimary
        }
    }

    @ViewBuilder
    private var fallbackIcon: some View {
        Text(ItemIconMapper.emoji(for: item.name, category: item.category))
            .font(BrandFont.regular(22))
            .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
            .background(stateAccentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius))
    }

    private var pantryPhotoURL: URL? {
        guard let photoPath = item.photoPath, !photoPath.isEmpty else { return nil }
        return Self.photoStorage.publicURL(for: photoPath)
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
        case .expired: .gsDanger
        case .expiringSoon: .gsWarning
        default: .gsTextSecondary
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

// MARK: - Optional tap (edit) without nested Buttons

private struct OptionalTapGestureModifier: ViewModifier {
    let action: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
