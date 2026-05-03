import SwiftUI
import UIKit

// MARK: - Font registration
// Inter + Outfit (Google Fonts variable TTFs) + IBM Plex Mono static TTFs in GrubShelf/Fonts/
// Registered via Info.plist / project.yml `UIAppFonts`:
//   - Inter-Variable.ttf, Outfit-Variable.ttf
//   - IBMPlexMono-Regular.ttf, IBMPlexMono-SemiBold.ttf, IBMPlexMono-Bold.ttf

private enum BrandFontFamily {
    static let sans = "Inter"
    static let display = "Outfit"
    static let monoRegular = "IBMPlexMono-Regular"
    static let monoSemiBold = "IBMPlexMono-SemiBold"
    static let monoBold = "IBMPlexMono-Bold"
}

struct BrandFont {
    /// Maps SwiftUI `Font.Weight` to UIKit for variable sans/display faces.
    static func uiKitWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    fileprivate static func variableUIFont(family: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            UIFontDescriptor.AttributeName.family: family,
            UIFontDescriptor.AttributeName.traits: [
                UIFontDescriptor.TraitKey.weight: weight.rawValue
            ]
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        if font.familyName == family || font.fontName.lowercased().contains(family.lowercased()) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    fileprivate static func variableFont(family: String, size: CGFloat, weight: Font.Weight) -> Font {
        Font(variableUIFont(family: family, size: size, weight: uiKitWeight(weight)))
    }

    // MARK: - Inter (UI / body / nav — Tailwind `font-sans`)

    static func regular(_ size: CGFloat) -> Font {
        variableFont(family: BrandFontFamily.sans, size: size, weight: .regular)
    }
    static func medium(_ size: CGFloat) -> Font {
        variableFont(family: BrandFontFamily.sans, size: size, weight: .medium)
    }
    static func semiBold(_ size: CGFloat) -> Font {
        variableFont(family: BrandFontFamily.sans, size: size, weight: .semibold)
    }
    static func bold(_ size: CGFloat) -> Font {
        variableFont(family: BrandFontFamily.sans, size: size, weight: .bold)
    }

    // MARK: - IBM Plex Mono (`font-mono`)

    static func mono(_ size: CGFloat) -> Font {
        if UIFont(name: BrandFontFamily.monoRegular, size: size) != nil {
            return .custom(BrandFontFamily.monoRegular, size: size)
        }
        return .system(size: size, weight: .regular, design: .monospaced)
    }
    static func monoBold(_ size: CGFloat) -> Font {
        if UIFont(name: BrandFontFamily.monoBold, size: size) != nil {
            return .custom(BrandFontFamily.monoBold, size: size)
        }
        return .system(size: size, weight: .bold, design: .monospaced)
    }

    // MARK: - UIKit (AVKit overlays, etc.)

    static func uiFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        variableUIFont(family: BrandFontFamily.sans, size: size, weight: weight)
    }
}

// MARK: - Outfit display (`font-display`)

enum BrandDisplayFont {
    static func regular(_ size: CGFloat) -> Font {
        BrandFont.variableFont(family: BrandFontFamily.display, size: size, weight: .regular)
    }
    static func medium(_ size: CGFloat) -> Font {
        BrandFont.variableFont(family: BrandFontFamily.display, size: size, weight: .medium)
    }
    static func semiBold(_ size: CGFloat) -> Font {
        BrandFont.variableFont(family: BrandFontFamily.display, size: size, weight: .semibold)
    }
    static func bold(_ size: CGFloat) -> Font {
        BrandFont.variableFont(family: BrandFontFamily.display, size: size, weight: .bold)
    }
}

// MARK: - SF Symbols
/// SF Symbols align to the system font grid; centralize point sizes here instead of ad hoc `.system` calls.
enum BrandSymbolFont {
    static func symbol(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Predefined type styles
extension View {
    func gsDisplayLarge() -> some View {
        self.font(BrandDisplayFont.bold(34))
            .tracking(-1.0)
            .lineSpacing(34 * 0.1)
            .foregroundColor(.gsTextPrimary)
    }
    func gsDisplayMedium() -> some View {
        self.font(BrandDisplayFont.bold(30))
            .tracking(-0.8)
            .lineSpacing(30 * 0.15)
            .foregroundColor(.gsTextPrimary)
    }
    func gsHeadingLarge() -> some View {
        self.font(BrandFont.bold(26))
            .tracking(-0.5)
            .foregroundColor(.gsTextPrimary)
    }
    func gsHeadingMedium() -> some View {
        self.font(BrandFont.bold(22))
            .tracking(-0.3)
            .foregroundColor(.gsTextPrimary)
    }
    func gsHeadingSmall() -> some View {
        self.font(BrandFont.semiBold(18))
            .foregroundColor(.gsTextPrimary)
    }
    func gsBodyLarge() -> some View {
        self.font(BrandFont.regular(18))
            .lineSpacing(18 * 0.6)
            .foregroundColor(.gsTextPrimary)
    }
    func gsBody() -> some View {
        self.font(BrandFont.regular(17))
            .lineSpacing(17 * 0.6)
            .foregroundColor(.gsTextPrimary)
    }
    func gsBodySmall() -> some View {
        self.font(BrandFont.regular(15))
            .lineSpacing(15 * 0.5)
            .foregroundColor(.gsTextSecondary)
    }
    func gsCaption() -> some View {
        self.font(BrandFont.regular(14))
            .tracking(0.2)
            .foregroundColor(.gsTextTertiary)
    }
    func gsLabel() -> some View {
        self.font(BrandFont.monoSemiBoldUIFont(size: 13))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(.gsTextSecondary)
    }
    func gsOverline() -> some View {
        self.font(BrandFont.monoMediumUIFont(size: 13))
            .tracking(3.0)
            .textCase(.uppercase)
            .foregroundColor(.gsTextTertiary)
    }
    func gsDataLarge() -> some View {
        self.font(BrandFont.bold(22))
            .foregroundColor(.gsTextPrimary)
    }
    func gsData() -> some View {
        self.font(BrandFont.mono(16))
            .foregroundColor(.gsTextPrimary)
    }
    func gsDataSmall() -> some View {
        self.font(BrandFont.mono(14))
            .foregroundColor(.gsTextSecondary)
    }
}

private extension BrandFont {
    static func monoMediumUIFont(size: CGFloat) -> Font {
        if UIFont(name: BrandFontFamily.monoRegular, size: size) != nil {
            return .custom(BrandFontFamily.monoRegular, size: size)
        }
        return .system(size: size, weight: .medium, design: .monospaced)
    }

    static func monoSemiBoldUIFont(size: CGFloat) -> Font {
        if UIFont(name: BrandFontFamily.monoSemiBold, size: size) != nil {
            return .custom(BrandFontFamily.monoSemiBold, size: size)
        }
        return .system(size: size, weight: .semibold, design: .monospaced)
    }
}
