import XCTest

@testable import GrubShelf

final class DashboardResponsiveLayoutTests: XCTestCase {
    func testPackedRowFits_emptyItemCount_returnsTrue() {
        XCTAssertTrue(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 0,
                minItemWidth: 100,
                interItemSpacing: 10,
                horizontalInset: 16,
                containerWidth: 100
            )
        )
    }

    func testPackedRowFits_zeroContainerWidth_returnsFalseWhenItemsPresent() {
        XCTAssertFalse(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 2,
                minItemWidth: 50,
                interItemSpacing: 0,
                horizontalInset: 0,
                containerWidth: 0
            )
        )
    }

    func testPackedRowFits_twoCards_iPhoneWidth_fits() {
        // 390pt class device, 16pt margins → 358pt inner; two 106pt cards + 10pt gap = 222
        XCTAssertTrue(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 2,
                minItemWidth: DashboardResponsiveLayout.insightsCarouselPackedMinCardWidth,
                interItemSpacing: 10,
                horizontalInset: AppSpacing.screenPadding,
                containerWidth: 390
            )
        )
    }

    func testPackedRowFits_threeCards_iPhoneWidth_fitsAtMinWidth() {
        // 3×106 + 2×10 = 338 ≤ 358
        XCTAssertTrue(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 3,
                minItemWidth: DashboardResponsiveLayout.insightsCarouselPackedMinCardWidth,
                interItemSpacing: AppSpacing.mediumSpacing,
                horizontalInset: AppSpacing.screenPadding,
                containerWidth: 390
            )
        )
    }

    func testPackedRowFits_fourCards_iPhoneWidth_doesNotFit() {
        // 4×106 + 3×10 = 454 > 358
        XCTAssertFalse(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 4,
                minItemWidth: DashboardResponsiveLayout.insightsCarouselPackedMinCardWidth,
                interItemSpacing: AppSpacing.mediumSpacing,
                horizontalInset: AppSpacing.screenPadding,
                containerWidth: 390
            )
        )
    }

    func testPackedRowFits_storyStripSixBubbles_narrowPhone_doesNotFit() {
        XCTAssertFalse(
            DashboardResponsiveLayout.packedEqualWidthRowFits(
                itemCount: 6,
                minItemWidth: DashboardResponsiveLayout.storyStripPackedMinColumnWidth,
                interItemSpacing: AppSpacing.cardPadding,
                horizontalInset: AppSpacing.screenPadding,
                containerWidth: 320
            )
        )
        let innerWidth = 320 - 2 * AppSpacing.screenPadding
        XCTAssertGreaterThan(
            6 * DashboardResponsiveLayout.storyStripPackedMinColumnWidth + 5 * AppSpacing.cardPadding,
            innerWidth
        )
    }
}
