import CoreText
import UIKit

/// Ensures custom brand fonts are available before any UI runs.
/// `UIAppFonts` in Info.plist is the primary mechanism; this registers any `.ttf`
/// in the main bundle if faces are still missing (mis-merge / cache issues).
enum BundledFontRegistration {
    /// PostScript name for the default instance of the bundled Inter variable font (Google Fonts metadata).
    private static let probeName = "Inter-Regular"
    private static let probeSize: CGFloat = 12

    static func ensureBrandFontsLoaded() {
        if UIFont(name: probeName, size: probeSize) != nil { return }

        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil), !urls.isEmpty else {
            #if DEBUG
            print("GrubShelf: no .ttf in bundle — verify Copy Bundle Resources and UIAppFonts.")
            #endif
            return
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }

        #if DEBUG
        if UIFont(name: probeName, size: probeSize) == nil {
            print("GrubShelf: brand fonts failed to load. Bundle TTFs: \(urls.map(\.lastPathComponent))")
        }
        #endif
    }
}
