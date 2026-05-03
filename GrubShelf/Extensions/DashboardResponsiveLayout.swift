import CoreGraphics

/// Sizing helpers for dashboard rows that switch between a packed (no horizontal scroll) layout
/// and a horizontal carousel. `ViewThatFits` in views uses the same minimum widths as these constants.
enum DashboardResponsiveLayout {
    /// Minimum width per insight card when showing all cards in one `HStack` (readable two-line body text).
    static let insightsCarouselPackedMinCardWidth: CGFloat = 106

    /// Minimum width per story-strip bubble column (56pt ring + label).
    static let storyStripPackedMinColumnWidth: CGFloat = 56

    /// Returns whether `itemCount` items can each be at least `minItemWidth` wide inside `containerWidth`
    /// with symmetric `horizontalInset` and `interItemSpacing` between items.
    static func packedEqualWidthRowFits(
        itemCount: Int,
        minItemWidth: CGFloat,
        interItemSpacing: CGFloat,
        horizontalInset: CGFloat,
        containerWidth: CGFloat
    ) -> Bool {
        guard itemCount > 0 else { return true }
        guard containerWidth > 0 else { return false }
        let gapTotal = CGFloat(max(0, itemCount - 1)) * interItemSpacing
        let cellsTotal = CGFloat(itemCount) * minItemWidth
        let required = cellsTotal + gapTotal
        let available = containerWidth - horizontalInset * 2
        return required <= available
    }
}
