import SwiftUI

/// Trailing toolbar: primary green SF Symbol, no glass/chrome (same family as Pantry/Shop add).
struct PrimaryToolbarIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: systemImage)
                .font(BrandSymbolFont.symbol(20, weight: .semibold))
                .foregroundStyle(.gsBrandPrimary)
                .symbolRenderingMode(.monochrome)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

/// Trailing nav add: **`plus.circle`** (single composed glyph).
struct PrimaryPlusToolbarButton: View {
    let accessibilityLabel: String
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        PrimaryToolbarIconButton(
            systemImage: "plus.circle",
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            action: action
        )
    }
}

/// Gentle spring-scale press effect used on dashboard cards and tappable rows.
struct DashboardScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
