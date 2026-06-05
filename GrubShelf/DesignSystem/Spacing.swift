import SwiftUI

/// Layout spacing for GrubShelf. **Do not use raw numbers** for padding or stack spacing in views —
/// use these tokens so spacing stays consistent. See `docs/SPACING.md`.
enum AppSpacing {
    // MARK: - Core scale (points)

    /// 2pt — paired meta lines (title + subtitle), filter glyph vertical inset, list row bonus inset.
    static let microGap: CGFloat = 2

    /// 4pt — tight label stacks, grid cell gap, chip inner vertical padding, icon–text in compact rows.
    static let compactGap: CGFloat = 4

    /// 5pt — horizontal spacing between elements inside filter capsule chips.
    static let filterChipInnerSpacing: CGFloat = 5

    /// 6pt — dense list row rhythm (`rowSpacing / 2`), skeleton lines, filter glyph horizontal inset.
    static let denseSpacing: CGFloat = 6

    /// 8pt — secondary vertical/horizontal stack spacing, tab bar top inset, banners.
    static let smallSpacing: CGFloat = 8

    /// 10pt — compact control rhythm (badges, transfer summary rows, toast icon row); equals filter capsule outer horizontal padding.
    static let mediumSpacing: CGFloat = 10

    /// 12pt — default spacing between primary rows; toolbar label horizontal padding.
    static let rowSpacing: CGFloat = 12

    /// 16pt — horizontal margins from screen edges (also used as default list leading/trailing).
    static let screenPadding: CGFloat = 16

    /// 16pt — interior padding for card-style surfaces (same value as `screenPadding`, distinct semantics).
    static let cardPadding: CGFloat = 16

    /// 24pt — spacing between major sections (onboarding steps, sheet blocks).
    static let sectionSpacing: CGFloat = 24

    /// Vertical gap between Home header blocks (greeting, summary carousel, review strip).
    static let homeChromeVerticalSpacing: CGFloat = 16

    // MARK: - Semantic components

    /// Vertical padding on the outer filter chip capsule (Home, Pantry).
    /// Increased to meet 44pt minimum touch target (accessibility requirement).
    static let filterChipOuterVerticalPadding: CGFloat = 14

    /// Vertical padding on compact priority chips in Home chrome (capsule rows).
    /// Priority chips on Home (Expiring / Low stock / Review) — taller for visibility.
    /// Increased to meet 44pt minimum touch target (accessibility requirement).
    static let priorityChipVerticalPadding: CGFloat = 14

    /// Inner vertical padding for the toast bubble.
    static let toastVerticalPadding: CGFloat = 14

    // MARK: - Radii (grouped with spacing file for layout-adjacent tokens)

    static let cardRadius: CGFloat = 16
    static let heroRadius: CGFloat = 24
    static let buttonRadius: CGFloat = 12
    static let iconRadius: CGFloat = 10

    /// Status chips, calendar day cells, and similar compact pills (8pt).
    static let badgeCornerRadius: CGFloat = 8

    /// Compact banners and inline strips between `buttonRadius` and `cardRadius` (e.g. review CTA, quick-action chrome).
    static let bannerCornerRadius: CGFloat = 14

    // MARK: - List & scroll alignment

    /// Card-style list rows: same horizontal inset as screen margins; vertical rhythm matches across Home, Pantry, and Shopping.
    static var listRowCardInsets: EdgeInsets {
        EdgeInsets(
            top: denseSpacing + microGap,
            leading: screenPadding,
            bottom: denseSpacing + microGap,
            trailing: screenPadding
        )
    }

    /// Segmented controls and other full-width controls inside a list section.
    static var listRowSectionControlInsets: EdgeInsets {
        EdgeInsets(
            top: rowSpacing,
            leading: screenPadding,
            bottom: rowSpacing,
            trailing: screenPadding
        )
    }

    // MARK: - Touch & rows

    static let minTouchTarget: CGFloat = 44

    /// Inline search field row — tighter than `minTouchTarget` so it matches typical search bars.
    static let inlineSearchRowMinHeight: CGFloat = 36

    /// Vertical padding inside cards that wrap `InlineSearchFieldRow`.
    static let inlineSearchCardVerticalPadding: CGFloat = 10

    /// Bottom inset for scrollable content behind the floating + button (56pt + padding). Use when scroll views sit under the FAB.
    static let floatingAddButtonScrollClearance: CGFloat = 72

    /// Minimum vertical `Spacer` length for empty states, onboarding, and list chrome breathing room.
    static let scrollVerticalBreathingRoom: CGFloat = 40

    /// Bottom inset for barcode scanner instruction stack from the safe area.
    static let scannerOverlayBottomInset: CGFloat = 40

    /// Minimum width for mono quantity column in pantry rows.
    static let quantityColumnMinWidth: CGFloat = 24

    // MARK: - Icon containers

    static let iconSizeLarge: CGFloat = 48
    static let iconSizeMedium: CGFloat = 40
    static let iconSizeSmall: CGFloat = 36

    // MARK: - Compact controls & indicators

    /// 3pt — expiry calendar dot, tiny presence indicators.
    static let dotSize: CGFloat = 3
    /// Active page indicator capsule width (onboarding).
    static let pageIndicatorActiveWidth: CGFloat = 16
    /// Page indicator capsule / dot height (onboarding).
    static let pageIndicatorHeight: CGFloat = 4
    /// Chevron touch-target width (calendar nav arrows).
    static let chevronTouchWidth: CGFloat = 28
    /// Chevron touch-target height (calendar nav arrows).
    static let chevronTouchHeight: CGFloat = 32
    /// Compact cell corner radius (calendar day cells).
    static let cellRadius: CGFloat = 6
    /// Small avatar circle (onboarding household demo).
    static let avatarSizeSmall: CGFloat = 52
    /// Photo thumbnail in recognition results.
    static let photoThumbnailSize: CGFloat = 64
    /// Quick-add card dimensions in the add-item hub.
    static let quickAddCardSize: CGFloat = 96

    // MARK: - Shadow

    static let shadowOpacity: Double = 0.08
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
}
