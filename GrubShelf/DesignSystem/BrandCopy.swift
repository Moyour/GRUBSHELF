import Foundation

/// User-facing product name and taglines. Keep spelling and capitalization consistent everywhere (onboarding → main app → legal).
enum BrandCopy {
    static let displayName = "Grub Shelf"

    /// One-word mark for sign-in chrome (Welcome, email auth header).
    static let wordmark = "GrubShelf"

    /// Shown on onboarding and anywhere we need one calm line of positioning.
    static let welcomeTagline = "Pantry, shop, and spend — in one calm place"

    static let aboutDescription =
        "\(displayName) helps your household track pantry items, plan shopping trips, and reduce food waste — all in one simple app."
}
