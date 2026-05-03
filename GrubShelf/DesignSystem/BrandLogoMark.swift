import SwiftUI

/// App mark from asset catalog (`brand-logo`), kept in sync with `AppIcon` artwork.
struct BrandLogoMark: View {
    var size: CGFloat = 56
    /// When non-nil, clips with a continuous rounded rect (on-screen app icon style).
    var cornerRadius: CGFloat? = nil

    /// Corner radius matching the iOS app icon mask proportion (~22.37% of side length).
    static func iconCornerRadius(forSide side: CGFloat) -> CGFloat {
        side * 0.2237
    }

    var body: some View {
        let image = Image("brand-logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)

        Group {
            if let cornerRadius, cornerRadius > 0 {
                image.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                image
            }
        }
        .accessibilityLabel(BrandCopy.displayName)
    }
}
