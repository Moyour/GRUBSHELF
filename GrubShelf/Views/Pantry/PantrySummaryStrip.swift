import SwiftUI

// MARK: - Pantry top summary (filter chips + counts; dashboard owns “at a glance” copy)

private struct PantryMetricTile: View {
    let systemName: String
    let gradient: [Color]
    let value: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                    .strokeBorder(
                        isSelected ? BrandPalette.Teal.s500 : Color.gsBorder.opacity(0.5),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .shadow(color: isSelected ? BrandPalette.Teal.s500.opacity(0.12) : .black.opacity(0.04), radius: isSelected ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct PantrySummaryStrip: View {
    @Bindable var viewModel: PantryViewModel

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.smallSpacing) {
            PantryMetricTile(
                systemName: "cabinet.fill",
                gradient: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
                value: "\(viewModel.pantryTotalActiveCount)",
                label: String(localized: "All items"),
                isSelected: viewModel.selectedAttention == .none
            ) {
                viewModel.selectedAttention = .none
            }
            PantryMetricTile(
                systemName: "clock.badge.exclamationmark.fill",
                gradient: [BrandPalette.Amber.s400, BrandPalette.Amber.s700],
                value: "\(viewModel.pantryExpiringAttentionCount)",
                label: String(localized: "Expiring"),
                isSelected: viewModel.selectedAttention == .expiring
            ) {
                if viewModel.selectedAttention == .expiring {
                    viewModel.setAttention(.none)
                } else {
                    viewModel.setAttention(.expiring)
                }
            }
            PantryMetricTile(
                systemName: "arrow.down.circle.fill",
                gradient: [Color.gsDanger.opacity(0.85), BrandPalette.Status.danger],
                value: "\(viewModel.pantryLowStockAttentionCount)",
                label: String(localized: "Low stock"),
                isSelected: viewModel.selectedAttention == .lowStock
            ) {
                if viewModel.selectedAttention == .lowStock {
                    viewModel.selectedAttention = .none
                } else {
                    viewModel.selectedAttention = .lowStock
                }
            }
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
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.bottom, AppSpacing.rowSpacing)
    }
}
