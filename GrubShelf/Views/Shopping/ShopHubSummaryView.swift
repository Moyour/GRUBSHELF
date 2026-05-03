import SwiftUI

// MARK: - Shop hub summary (metric tiles; dashboard owns “at a glance” copy)

private struct ShopHubMetricTile: View {
    let systemName: String
    let gradient: [Color]
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            HStack(alignment: .top, spacing: AppSpacing.compactGap) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 30, height: 30)
                        .shadow(color: gradient.last?.opacity(0.25) ?? .clear, radius: 4, x: 0, y: 2)
                    Image(systemName: systemName)
                        .font(BrandSymbolFont.symbol(13, weight: .semibold))
                        .foregroundStyle(.gsTextOnBrand)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(BrandFont.bold(26))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: value)
            }
            Text(label)
                .font(BrandFont.semiBold(14))
                .foregroundStyle(.gsTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.rowSpacing)
        .background(Color.gsSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                .strokeBorder(Color.gsBorder.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct ShopHubSummaryView: View {
    let summary: ShoppingHubSummary

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.smallSpacing) {
            ShopHubMetricTile(
                systemName: "list.bullet.rectangle.fill",
                gradient: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
                value: "\(summary.listCount)",
                label: String(localized: "Lists")
            )
            ShopHubMetricTile(
                systemName: "cart.fill",
                gradient: [BrandPalette.Amber.s400, BrandPalette.Amber.s700],
                value: "\(summary.pendingTotal)",
                label: String(localized: "To buy")
            )
            ShopHubMetricTile(
                systemName: "checkmark.circle.fill",
                gradient: [BrandPalette.Teal.s300, BrandPalette.Teal.s600],
                value: "\(summary.completedTotal)",
                label: String(localized: "Checked")
            )
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.heroRadius, style: .continuous)
                .fill(Color.gsSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.heroRadius, style: .continuous)
                .strokeBorder(Color.gsBorder.opacity(0.45), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.listCount) lists, \(summary.pendingTotal) to buy, \(summary.completedTotal) checked off"
        )
    }
}
