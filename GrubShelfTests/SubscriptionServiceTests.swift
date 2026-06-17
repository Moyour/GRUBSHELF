import XCTest
@testable import GrubShelf

@MainActor
final class SubscriptionServiceTests: XCTestCase {

    func testDefaultStateIsFree() {
        let service = SubscriptionService()
        XCTAssertTrue(service.isFree)
        XCTAssertFalse(service.isPremium)
        XCTAssertNil(service.currentPlan)
    }

    func testCanUseFeatureWithoutPlan() {
        let service = SubscriptionService()
        // No plan loaded — should be permissive
        XCTAssertTrue(service.canUseFeature(.exportReports))
        XCTAssertTrue(service.canUseFeature(.photoUploads))
    }

    func testCanUseFeatureWithFreePlan() {
        let service = SubscriptionService()
        service.currentPlan = MockSubscriptionService.freePlan()

        XCTAssertFalse(service.canUseFeature(.exportReports))
        XCTAssertFalse(service.canUseFeature(.photoUploads))
        XCTAssertFalse(service.canUseFeature(.bulkOperations))
    }

    func testCanUseFeatureWithPremiumPlan() {
        let service = SubscriptionService()
        service.currentPlan = MockSubscriptionService.premiumPlan()

        XCTAssertTrue(service.canUseFeature(.exportReports))
        XCTAssertTrue(service.canUseFeature(.photoUploads))
        XCTAssertTrue(service.canUseFeature(.bulkOperations))
    }

    func testIsPremiumWithPremiumPlan() {
        let service = SubscriptionService()
        service.currentPlan = MockSubscriptionService.premiumPlan()

        XCTAssertTrue(service.isPremium)
        XCTAssertFalse(service.isFree)
    }

    func testOfflineCacheRoundTrip() {
        let key = "com.grubshelf.subscriptionPlanCache"

        // Clear any existing cache
        UserDefaults.standard.removeObject(forKey: key)

        let plan = MockSubscriptionService.premiumPlan()
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }

        let service = SubscriptionService()
        XCTAssertNotNil(service.currentPlan)
        XCTAssertTrue(service.isPremium)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
}
