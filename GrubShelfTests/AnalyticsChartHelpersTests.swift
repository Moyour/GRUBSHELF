import XCTest

@testable import GrubShelf

final class AnalyticsChartHelpersTests: XCTestCase {
    func testCategoryPieSlices_EmptyRows() {
        XCTAssertTrue(AnalyticsChartHelpers.categoryPieSlices(from: [], maxSlices: 5).isEmpty)
    }

    func testCategoryPieSlices_MaxSlicesZero() {
        let rows = [CategorySpend(category: "A", amount: 3)]
        XCTAssertTrue(AnalyticsChartHelpers.categoryPieSlices(from: rows, maxSlices: 0).isEmpty)
    }

    func testCategoryPieSlices_FewerRowsThanCap_NoOtherBucket() {
        let rows = [
            CategorySpend(category: "Dairy", amount: 4),
            CategorySpend(category: "Produce", amount: 2)
        ]
        let slices = AnalyticsChartHelpers.categoryPieSlices(from: rows, maxSlices: 5)
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices.map(\.name), ["Dairy", "Produce"])
        XCTAssertEqual(slices.map(\.count), [4, 2])
    }

    func testCategoryPieSlices_MoreRowsThanCap_AggregatesOther() {
        let rows = [
            CategorySpend(category: "A", amount: 10),
            CategorySpend(category: "B", amount: 8),
            CategorySpend(category: "C", amount: 6),
            CategorySpend(category: "D", amount: 4),
            CategorySpend(category: "E", amount: 2),
            CategorySpend(category: "F", amount: 1)
        ]
        let slices = AnalyticsChartHelpers.categoryPieSlices(from: rows, maxSlices: 5)
        XCTAssertEqual(slices.count, 6)
        XCTAssertEqual(slices.last?.name, "Other")
        XCTAssertEqual(slices.last?.count, 1)
        XCTAssertEqual(slices.prefix(5).map(\.count), [10, 8, 6, 4, 2])
    }

    func testCategoryPieSlices_TailSumZero_OmitsOther() {
        let rows = [
            CategorySpend(category: "A", amount: 5),
            CategorySpend(category: "B", amount: 3),
            CategorySpend(category: "C", amount: 0),
            CategorySpend(category: "D", amount: 0)
        ]
        let slices = AnalyticsChartHelpers.categoryPieSlices(from: rows, maxSlices: 2)
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices.map(\.name), ["A", "B"])
    }
}
