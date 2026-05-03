import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: "plus")
                .font(BrandSymbolFont.symbol(24, weight: .semibold))
                .foregroundStyle(.gsTextInverse)
                .frame(width: 56, height: 56)
                .background(.gsBrandPrimary, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleOnPressButtonStyle())
        .accessibilityLabel("Add item")
        .accessibilityHint("Double tap to add a new pantry item")
    }
}

private struct ScaleOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

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

/// Reusable glassy toolbar icon button with primaryGreen accent. Use for top-right nav bar actions.
struct GlassyToolbarIconButton: View {
    let systemImage: String
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let action: () -> Void

    init(
        systemImage: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: systemImage)
                .font(BrandSymbolFont.symbol(17, weight: .semibold))
                .foregroundStyle(.gsBrandPrimary)
                .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.iconRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemImage)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

/// Glassy toolbar button with icon and label (e.g. "Invite" + person.badge.plus).
struct GlassyToolbarLabelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsBrandPrimary)
                .padding(.horizontal, AppSpacing.rowSpacing)
                .padding(.vertical, AppSpacing.smallSpacing)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.iconRadius))
        }
        .buttonStyle(.plain)
    }
}
