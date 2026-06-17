import XCTest
@testable import GrubShelf

final class SubscriptionModelTests: XCTestCase {

    // MARK: - FeatureLimitValue

    func testFeatureLimitValueUnlimited() throws {
        let json = "-1"
        let value = try JSONDecoder().decode(FeatureLimitValue.self, from: Data(json.utf8))
        XCTAssertEqual(value, .unlimited)
        XCTAssertTrue(value.isUnlimited)
        XCTAssertNil(value.numericLimit)
    }

    func testFeatureLimitValueLimited() throws {
        let json = "150"
        let value = try JSONDecoder().decode(FeatureLimitValue.self, from: Data(json.utf8))
        XCTAssertEqual(value, .limited(150))
        XCTAssertFalse(value.isUnlimited)
        XCTAssertEqual(value.numericLimit, 150)
    }

    func testFeatureLimitValueRoundTrip() throws {
        let original = FeatureLimitValue.limited(20)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureLimitValue.self, from: data)
        XCTAssertEqual(original, decoded)

        let unlim = FeatureLimitValue.unlimited
        let data2 = try JSONEncoder().encode(unlim)
        let decoded2 = try JSONDecoder().decode(FeatureLimitValue.self, from: data2)
        XCTAssertEqual(unlim, decoded2)
    }

    // MARK: - FeatureLimits

    func testFeatureLimitsDecodingFromJSON() throws {
        let json = """
        {
            "household_members": 2,
            "pantry_items": 150,
            "shopping_lists": 3,
            "barcode_scans_per_month": 20,
            "analytics_days": 7,
            "export_reports": false,
            "photo_uploads": false,
            "bulk_operations": false
        }
        """
        let limits = try JSONDecoder().decode(FeatureLimits.self, from: Data(json.utf8))
        XCTAssertEqual(limits.householdMembers, .limited(2))
        XCTAssertEqual(limits.pantryItems, .limited(150))
        XCTAssertEqual(limits.shoppingLists, .limited(3))
        XCTAssertEqual(limits.barcodeScansPerMonth, .limited(20))
        XCTAssertEqual(limits.analyticsDays, .limited(7))
        XCTAssertFalse(limits.exportReports)
        XCTAssertFalse(limits.photoUploads)
        XCTAssertFalse(limits.bulkOperations)
    }

    func testPremiumFeaturesDecoding() throws {
        let json = """
        {
            "household_members": -1,
            "pantry_items": -1,
            "shopping_lists": -1,
            "barcode_scans_per_month": -1,
            "analytics_days": -1,
            "export_reports": true,
            "photo_uploads": true,
            "bulk_operations": true
        }
        """
        let limits = try JSONDecoder().decode(FeatureLimits.self, from: Data(json.utf8))
        XCTAssertEqual(limits.householdMembers, .unlimited)
        XCTAssertEqual(limits.pantryItems, .unlimited)
        XCTAssertTrue(limits.exportReports)
        XCTAssertTrue(limits.photoUploads)
        XCTAssertTrue(limits.bulkOperations)
    }

    // MARK: - FeatureLimitCheck

    func testUsagePercentage() {
        let check = FeatureLimitCheck(canPerform: true, currentUsage: 120, limitValue: 150, isUnlimited: false)
        XCTAssertEqual(check.usagePercentage, 0.8, accuracy: 0.001)
        XCTAssertTrue(check.isNearLimit)
        XCTAssertEqual(check.remainingCount, 30)
    }

    func testUsagePercentageUnlimited() {
        let check = FeatureLimitCheck(canPerform: true, currentUsage: 500, limitValue: -1, isUnlimited: true)
        XCTAssertEqual(check.usagePercentage, 0)
        XCTAssertFalse(check.isNearLimit)
        XCTAssertNil(check.remainingCount)
    }

    func testUsagePercentageAtLimit() {
        let check = FeatureLimitCheck(canPerform: false, currentUsage: 150, limitValue: 150, isUnlimited: false)
        XCTAssertEqual(check.usagePercentage, 1.0, accuracy: 0.001)
        XCTAssertTrue(check.isNearLimit)
        XCTAssertEqual(check.remainingCount, 0)
    }

    // MARK: - SubscriptionPlan

    func testSubscriptionPlanIsPremium() {
        let plan = makeTestPlan(name: "premium")
        XCTAssertTrue(plan.isPremium)
        XCTAssertFalse(plan.isFree)
    }

    func testSubscriptionPlanIsFree() {
        let plan = makeTestPlan(name: "free")
        XCTAssertFalse(plan.isPremium)
        XCTAssertTrue(plan.isFree)
    }

    func testPriceFormatting() {
        let plan = makeTestPlan(name: "premium", monthlyCents: 499, yearlyCents: 5499)
        XCTAssertEqual(plan.monthlyPriceFormatted, "$4.99")
        XCTAssertEqual(plan.yearlyPriceFormatted, "$54.99")
    }

    // MARK: - SubscriptionFeature

    func testFeatureProperties() {
        XCTAssertTrue(SubscriptionFeature.barcodeScansPerMonth.isMetered)
        XCTAssertFalse(SubscriptionFeature.pantryItems.isMetered)

        XCTAssertTrue(SubscriptionFeature.pantryItems.isCountBased)
        XCTAssertTrue(SubscriptionFeature.shoppingLists.isCountBased)
        XCTAssertFalse(SubscriptionFeature.exportReports.isCountBased)

        XCTAssertTrue(SubscriptionFeature.exportReports.isBoolean)
        XCTAssertTrue(SubscriptionFeature.photoUploads.isBoolean)
        XCTAssertFalse(SubscriptionFeature.pantryItems.isBoolean)
    }

    // MARK: - Helpers

    private func makeTestPlan(
        name: String,
        monthlyCents: Int = 0,
        yearlyCents: Int = 0
    ) -> SubscriptionPlan {
        SubscriptionPlan(
            id: UUID(),
            name: name,
            displayName: name.capitalized,
            features: FeatureLimits(
                householdMembers: .limited(2),
                pantryItems: .limited(150),
                shoppingLists: .limited(3),
                barcodeScansPerMonth: .limited(20),
                analyticsDays: .limited(7),
                exportReports: false,
                photoUploads: false,
                bulkOperations: false
            ),
            priceMonthlyCents: monthlyCents,
            priceYearlyCents: yearlyCents,
            isActive: true
        )
    }
}
