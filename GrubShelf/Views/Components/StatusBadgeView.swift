import SwiftUI

/// Tag with icon: tinted background + small icon + colored text (light and dark).
///
/// Visual weight scales with urgency:
///   - Expired = danger (bold)
///   - Expiring / Low = warning (moderate)
///   - Review = brand primary (action: confirm still have / finished)
///   - Good / Done = success (calm)
///   - Neutral = secondary (quiet)
struct StatusBadgeView: View {
    let status: Status
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: AppSpacing.compactGap) {
            Image(systemName: status.icon)
                .font(BrandSymbolFont.symbol(10, weight: .semibold))
            Text(status.label)
                .font(BrandFont.semiBold(13))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .truncationMode(.tail)
        }
        .foregroundStyle(status.foregroundColor)
        .padding(.horizontal, AppSpacing.mediumSpacing)
        .padding(.vertical, AppSpacing.compactGap)
        .background(status.foregroundColor.opacity(colorScheme == .dark ? 0.15 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius))
    }

    enum Status {
        case expired
        case expiring
        case low
        case review
        case good
        case done
        case gone
        case check
        case custom(label: String, icon: String, color: Color)

        var label: String {
            switch self {
            case .expired:  return "Expired"
            case .expiring: return "Expiring"
            case .low:      return "Low"
            case .review:   return "Review"
            case .good:     return "Good"
            case .done:     return "Done"
            case .gone:     return "Gone?"
            case .check:    return "Check"
            case .custom(let label, _, _): return label
            }
        }

        var icon: String {
            switch self {
            case .expired:  return "exclamationmark.triangle.fill"
            case .expiring: return "clock.fill"
            case .low:      return "arrow.down.circle.fill"
            case .review:   return "eye.fill"
            case .good:     return "checkmark.circle.fill"
            case .done:     return "checkmark.circle.fill"
            case .gone:     return "questionmark.circle.fill"
            case .check:    return "questionmark.circle"
            case .custom(_, let icon, _): return icon
            }
        }

        var foregroundColor: Color {
            switch self {
            case .expired:  return .gsDanger
            case .expiring: return .gsWarning
            case .low:      return .gsWarning
            case .review:   return .gsBrandPrimary
            case .good:     return .gsSuccess
            case .done:     return .gsSuccess
            case .gone:     return .gsTextSecondary
            case .check:    return .gsTextSecondary
            case .custom(_, _, let color): return color
            }
        }
    }
}

extension StatusBadgeView.Status {
    init(itemState: ItemState, confidence: Double = 1.0) {
        switch itemState {
        case .expired:      self = .expired
        case .expiringSoon: self = .expiring
        case .lowStock:     self = .low
        case .stale:        self = .review
        case .active:
            if confidence < 0.3 {
                self = .gone
            } else if confidence < 0.7 {
                self = .check
            } else {
                self = .good
            }
        case .archived:     self = .gone
        }
    }
}
