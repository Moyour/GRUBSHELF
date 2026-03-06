import SwiftUI

enum AppFont {
    static let largeTitle: Font = .largeTitle.bold()
    static let sectionTitle: Font = .title3.weight(.semibold)
    static let body: Font = .body
    static let caption: Font = .caption
    static let button: Font = .body.weight(.semibold)

    // Hero & stat values
    static let greeting: Font = .system(size: 26, weight: .bold, design: .rounded)
    static let heroNumber: Font = .system(size: 60, weight: .bold, design: .rounded)
    static let statValue: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let statValueMedium: Font = .system(size: 20, weight: .bold, design: .rounded)
    static let statValueLarge: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let badgeLabel: Font = .system(size: 11, weight: .medium)
    static let badgeValue: Font = .system(size: 16, weight: .bold, design: .rounded)

    // Small detail text
    static let detail: Font = .system(size: 12, weight: .medium, design: .rounded)
    static let tinyLabel: Font = .system(size: 10, weight: .medium)

    // Empty state
    static let emptyStateIconSize: CGFloat = 60
    static let emptyStateIconSizeSecondary: CGFloat = 48
}
