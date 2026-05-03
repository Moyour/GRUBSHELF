import SwiftUI

struct SyncBanner: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: AppSpacing.smallSpacing) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(BrandSymbolFont.symbol(14))
                    .foregroundStyle(.gsTextInverse)
                Text(message)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextInverse)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.smallSpacing)
            .padding(.horizontal, AppSpacing.screenPadding)
            .background(.gsBrandPrimary)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
