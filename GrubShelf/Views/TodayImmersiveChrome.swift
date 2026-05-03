import SwiftUI

// MARK: - Hero (interactive focal point)

/// Large health ring + headline + three primary actions (Add / Pantry / Shop). Ring tap opens overview.
struct TodayDashboardHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    let greeting: String
    let headline: String
    let subtitle: String
    let healthScore: Int
    let healthLabel: String
    let animateScore: Bool
    let onTapRing: () -> Void
    let onAdd: () -> Void
    let onPantry: () -> Void
    let onShop: () -> Void

    private let ringSize: CGFloat = 102
    private let ringWidth: CGFloat = 7

    private var ringFraction: CGFloat {
        animateScore ? CGFloat(healthScore) / 100.0 : 0
    }

    private var heroCardRadius: CGFloat { AppSpacing.heroRadius }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(alignment: .top, spacing: AppSpacing.mediumSpacing) {
                VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                    Text(greeting)
                        .font(BrandFont.medium(12))
                        .foregroundStyle(.gsTextSecondary)
                        .tracking(1.4)
                        .textCase(.uppercase)

                    Text(headline)
                        .font(BrandFont.bold(30))
                        .tracking(-0.6)
                        .foregroundStyle(.gsTextPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(BrandFont.regular(16))
                        .foregroundStyle(.gsTextSecondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapRing()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gsBrandPrimary.opacity(0.08))
                            .frame(width: ringSize - ringWidth * 2, height: ringSize - ringWidth * 2)
                        Circle()
                            .stroke(Color.gsBorder.opacity(0.5), lineWidth: ringWidth)
                            .frame(width: ringSize, height: ringSize)
                        Circle()
                            .trim(from: 0, to: ringFraction)
                            .stroke(Color.gsBrandPrimary, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 3) {
                            Text("\(animateScore ? healthScore : 0)")
                                .font(BrandFont.bold(28))
                                .foregroundStyle(.gsTextPrimary)
                                .contentTransition(.numericText())
                            Text(healthLabel)
                                .font(BrandFont.medium(13))
                                .foregroundStyle(.gsTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                    }
                    .animation(.spring(response: 0.9, dampingFraction: 0.72), value: animateScore)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(BrandSymbolFont.symbol(22, weight: .semibold))
                            .foregroundStyle(.gsBrandPrimary.opacity(0.9))
                            .symbolRenderingMode(.hierarchical)
                            .offset(x: 8, y: 8)
                    }
                }
                .buttonStyle(DashboardScaleButtonStyle())
                .accessibilityLabel("Shelf health \(animateScore ? healthScore : 0) percent, \(healthLabel). Opens full overview.")
            }

            HStack(spacing: 0) {
                TodayHeroActionButton(title: "Add", systemImage: "plus", role: .primary, action: onAdd)
                heroActionDivider
                TodayHeroActionButton(title: "Pantry", systemImage: "refrigerator", role: .secondary, action: onPantry)
                heroActionDivider
                TodayHeroActionButton(title: "Shop", systemImage: "cart", role: .secondary, action: onShop)
            }
            .padding(AppSpacing.filterChipInnerSpacing)
            .background(
                RoundedRectangle(cornerRadius: heroCardRadius - 6, style: .continuous)
                    .fill(Color.gsBorder.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: heroCardRadius - 6, style: .continuous)
                    .strokeBorder(Color.gsBorder.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: heroCardRadius, style: .continuous)
                .fill(.gsSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: heroCardRadius, style: .continuous)
                .strokeBorder(Color.gsBorder.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 10)
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
        .offset(y: reduceMotion ? 0 : (appeared ? 0 : 16))
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82).delay(0.06)) {
                appeared = true
            }
        }
    }

    private var heroActionDivider: some View {
        Rectangle()
            .fill(Color.gsBorder.opacity(0.45))
            .frame(width: 1, height: AppSpacing.iconSizeSmall)
            .padding(.vertical, AppSpacing.compactGap)
    }
}

private enum TodayHeroActionRole {
    case primary
    case secondary
}

private struct TodayHeroActionButton: View {
    let title: String
    let systemImage: String
    let role: TodayHeroActionRole
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: AppSpacing.denseSpacing) {
                Image(systemName: systemImage)
                    .font(BrandSymbolFont.symbol(role == .primary ? 20 : 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(BrandFont.semiBold(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.rowSpacing)
            .foregroundStyle(role == .primary ? Color.gsTextInverse : Color.gsBrandPrimary)
            .background(
                Group {
                    if role == .primary {
                        RoundedRectangle(cornerRadius: AppSpacing.bannerCornerRadius, style: .continuous)
                            .fill(Color.gsBrandPrimary)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.97))
        .accessibilityLabel(title)
    }
}

// MARK: - Horizontal action cards

/// Tappable cards: Overview, Expiring, Shopping, Expense — swipe to explore.
struct TodayDashboardCardStrip: View {
    let healthScore: Int
    let healthLabel: String
    let animateScore: Bool
    let expiringCount: Int
    let shoppingLine: String
    let onOverview: () -> Void
    let onExpense: () -> Void
    let onShopping: () -> Void
    /// Expiring card (count > 0 should open calendar from parent; 0 opens pantry).
    let onExpiring: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.mediumSpacing) {
            HStack(spacing: AppSpacing.smallSpacing) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(BrandSymbolFont.symbol(13, weight: .semibold))
                    .foregroundStyle(.gsBrandPrimary.opacity(0.85))
                Text("Quick access")
                    .font(BrandFont.semiBold(13))
                    .foregroundStyle(.gsTextSecondary)
                    .textCase(.uppercase)
                    .tracking(1.1)
                Spacer()
                Image(systemName: "chevron.left.chevron.right")
                    .font(BrandSymbolFont.symbol(12, weight: .semibold))
                    .foregroundStyle(.gsTextTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quick access, swipe for shortcuts")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.mediumSpacing) {
                    DashboardStripCard(
                        icon: "square.grid.2x2.fill",
                        title: "Overview",
                        value: animateScore ? "\(healthScore)%" : "—",
                        subtitle: healthLabel,
                        accent: .gsBrandPrimary,
                        action: onOverview
                    )
                    .accessibilityLabel("Overview, shelf health \(healthScore) percent")

                    if expiringCount > 0 {
                        DashboardStripCard(
                            icon: "calendar.badge.clock",
                            title: "Expiring",
                            value: "\(expiringCount)",
                            subtitle: "Open calendar",
                            accent: .gsWarning,
                            action: onExpiring
                        )
                    } else {
                        DashboardStripCard(
                            icon: "checkmark.circle.fill",
                            title: "Dates",
                            value: "Clear",
                            subtitle: "No urgent items",
                            accent: .gsBrandPrimary,
                            action: onExpiring
                        )
                    }

                    DashboardStripCard(
                        icon: "cart.fill",
                        title: "Lists",
                        value: shoppingLine == "Nothing on your list" ? "Empty" : "Open",
                        subtitle: shoppingLine,
                        accent: .gsBrandPrimary,
                        action: onShopping
                    )

                    DashboardStripCard(
                        icon: "chart.bar.fill",
                        title: "Expense",
                        value: "Budget",
                        subtitle: "Spending & trips",
                        accent: .gsBrandPrimary,
                        action: onExpense
                    )
                }
                .padding(.trailing, AppSpacing.screenPadding)
            }
            .scrollClipDisabled()
        }
    }
}

private struct DashboardStripCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    private let cardWidth: CGFloat = 162
    private let iconTileSize: CGFloat = 46

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.bannerCornerRadius, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: iconTileSize, height: iconTileSize)
                    Image(systemName: icon)
                        .font(BrandSymbolFont.symbol(21, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(title)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextSecondary)
                Text(value)
                    .font(BrandFont.bold(24))
                    .tracking(-0.4)
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(width: cardWidth, alignment: .leading)
            .frame(minHeight: 168, alignment: .topLeading)
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                    .fill(.gsSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                    .strokeBorder(Color.gsBorder.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(DashboardScaleButtonStyle(scale: 0.98))
    }
}

// MARK: - Expiring rows (card containers)

struct TodayExpiringCardRow<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.rowSpacing)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                    .fill(.gsSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.heroRadius - 4, style: .continuous)
                    .strokeBorder(Color.gsBorder.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Shared interaction styles

struct DashboardScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
