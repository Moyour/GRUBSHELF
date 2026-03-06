import SwiftUI

extension View {
    /// Standard card shadow (radius 4, y 2, opacity 0.08)
    func cardShadow() -> some View {
        shadow(
            color: .black.opacity(AppSpacing.shadowOpacity),
            radius: AppSpacing.shadowRadius,
            x: 0,
            y: AppSpacing.shadowY
        )
    }

    /// Lighter shadow for pills/badges
    func pillShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}
