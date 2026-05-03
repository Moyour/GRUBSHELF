import SwiftUI

// MARK: - Metrics

enum EmptyStateMetrics {
    /// Raster illustration cap for tab empty states (Pantry / Shop).
    static let tabHeroImageMaxWidth: CGFloat = 148
    static let tabHeroImageMaxHeight: CGFloat = 118

    /// Illustration cap inside the pre-auth feature tour card.
    static let featureTourImageMaxWidth: CGFloat = 248
    static let featureTourImageMaxHeight: CGFloat = 176

    static let tabHeroSymbolSize: CGFloat = 34
    static let tabHeroSymbolSizeCompact: CGFloat = 30
}

// MARK: - Brand fills

enum EmptyStateChrome {
    static let symbolTealGradient = LinearGradient(
        colors: [BrandPalette.Teal.s400, BrandPalette.Teal.s700],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Tab empty hero (symbol + optional asset)

struct TabEmptyStateHero: View {
    let systemName: String
    var symbolFontSize: CGFloat = EmptyStateMetrics.tabHeroSymbolSize
    var symbolWeight: Font.Weight = .medium
    var imageAsset: String? = nil
    var pulse: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.compactGap) {
            Image(systemName: systemName)
                .font(BrandSymbolFont.symbol(symbolFontSize, weight: symbolWeight))
                .foregroundStyle(EmptyStateChrome.symbolTealGradient)
                .symbolEffect(.pulse, options: .repeating.speed(0.45), isActive: pulse)
                .accessibilityHidden(true)

            if let imageAsset {
                Image(imageAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: EmptyStateMetrics.tabHeroImageMaxWidth,
                        maxHeight: EmptyStateMetrics.tabHeroImageMaxHeight
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message card (dashboard surface)

struct EmptyStateCopyCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            Text(title)
                .font(BrandFont.semiBold(22))
                .foregroundStyle(.gsTextPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.smallSpacing)
        }
        .multilineTextAlignment(.center)
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .dashboardCardSurface()
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Primary CTA (brand fill)

struct EmptyStateTealCTAButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(BrandFont.semiBold(17))
            .foregroundStyle(.gsTextOnBrand)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minTouchTarget)
            .background(Color.gsBrandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
        }
    }
}

// MARK: - Inline empty (lists / pickers)

struct EmptyStateInlineBlock: View {
    let systemName: String
    var symbolSize: CGFloat = 28
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
            Image(systemName: systemName)
                .font(BrandSymbolFont.symbol(symbolSize, weight: .semibold))
                .foregroundStyle(EmptyStateChrome.symbolTealGradient)
                .accessibilityHidden(true)

            Text(title)
                .font(BrandFont.semiBold(18))
                .foregroundStyle(.gsTextPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(BrandFont.regular(16))
                .foregroundStyle(.gsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .dashboardCardSurface()
    }
}
