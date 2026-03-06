import SwiftUI

struct SyncBanner: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, AppSpacing.screenPadding)
            .background(Color.warningAmber)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
