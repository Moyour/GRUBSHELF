import SwiftUI

/// Banner that appears at the top of the screen when device is offline.
struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: AppSpacing.smallSpacing) {
            Image(systemName: "wifi.slash")
                .font(BrandSymbolFont.symbol(14, weight: .semibold))
                .foregroundStyle(.white)

            Text("No internet connection")
                .font(BrandFont.medium(14))
                .foregroundStyle(.white)

            Spacer()

            Text("Offline")
                .font(BrandFont.semiBold(12))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, AppSpacing.compactGap)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.smallSpacing)
        .background(.gsDanger)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
