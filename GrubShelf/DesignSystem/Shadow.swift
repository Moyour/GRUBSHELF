import SwiftUI

extension View {
    func cardShadow() -> some View {
        shadow(
            color: .black.opacity(AppSpacing.shadowOpacity),
            radius: AppSpacing.shadowRadius,
            x: 0,
            y: AppSpacing.shadowY
        )
    }

    /// Subtle elevation for a single hero element (e.g. insight carousel hero).
    @ViewBuilder
    func cardShadowIfHero(_ isHero: Bool) -> some View {
        if isHero {
            self.cardShadow()
        } else {
            self
        }
    }

    /// Default list/card surface: flat with a light border (no shadow) so screens don’t compete visually.
    func dashboardCardSurface() -> some View {
        background(Color.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.gsBorder.opacity(0.55), lineWidth: 1)
            )
    }

    /// Opt-in lift for rare primary surfaces.
    func dashboardCardSurfaceElevated() -> some View {
        background(Color.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.gsBorder.opacity(0.45), lineWidth: 1)
            )
            .cardShadow()
    }

    func pillShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}
