import XCTest

@testable import GrubShelf

final class ExpenseHeatmapBuilderTests: XCTestCase {
    func testNormalizedDays_IntensityScalesToMax() {
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 10
        let d1 = cal.date(from: c)!
        c.day = 11
        let d2 = cal.date(from: c)!

        let spend: [Date: Int] = [
            cal.startOfDay(for: d1): 1000,
            cal.startOfDay(for: d2): 500
        ]

        let out = ExpenseHeatmapBuilder.normalizedDays(
            calendarDays: [d1, d2],
            spendByStartOfDay: spend,
            calendar: cal
        )

        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].amountMinor, 1000)
        XCTAssertEqual(out[1].amountMinor, 500)
        XCTAssertEqual(out[0].intensity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(out[1].intensity, 0.5, accuracy: 0.0001)
    }

    func testNormalizedDays_AllZero_YieldsZeroIntensity() {
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 1
        let d1 = cal.date(from: c)!

        let out = ExpenseHeatmapBuilder.normalizedDays(
            calendarDays: [d1],
            spendByStartOfDay: [:],
            calendar: cal
        )

        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].amountMinor, 0)
        XCTAssertEqual(out[0].intensity, 0, accuracy: 0.0001)
    }

    func testDaysForBudgetPeriod_Monthly_ReturnsMonthDayCount() {
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 10
        let ref = cal.date(from: c)!

        let days = ExpenseHeatmapBuilder.daysForBudgetPeriod(
            budgetPeriod: .monthly,
            reference: ref,
            calendar: cal
        )

        XCTAssertEqual(days.count, 30) // April 2026 has 30 days
    }

    func testDaysForBudgetPeriod_Weekly_ReturnsSevenDays() {
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 10
        let ref = cal.date(from: c)!

        let days = ExpenseHeatmapBuilder.daysForBudgetPeriod(
            budgetPeriod: .weekly,
            reference: ref,
            calendar: cal
        )

        XCTAssertEqual(days.count, 7)
    }
}
