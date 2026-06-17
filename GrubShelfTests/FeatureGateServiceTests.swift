import XCTest
@testable import GrubShelf

@MainActor
final class FeatureGateServiceTests: XCTestCase {

    // MARK: - Boolean gates

    func testRequireFeatureReturnsTrueForPremium() {
        let subService = SubscriptionService()
        subService.currentPlan = MockSubscriptionService.premiumPlan()
        let gate = FeatureGateService(subscriptionService: subService)

        XCTAssertTrue(gate.requireFeature(.exportReports, showPaywallIfBlocked: false))
        XCTAssertTrue(gate.requireFeature(.photoUploads, showPaywallIfBlocked: false))
        XCTAssertTrue(gate.requireFeature(.bulkOperations, showPaywallIfBlocked: false))
    }

    func testRequireFeatureReturnsFalseForFree() {
        let subService = SubscriptionService()
        subService.currentPlan = MockSubscriptionService.freePlan()
        let gate = FeatureGateService(subscriptionService: subService)

        XCTAssertFalse(gate.requireFeature(.exportReports, showPaywallIfBlocked: false))
        XCTAssertFalse(gate.requireFeature(.photoUploads, showPaywallIfBlocked: false))
        XCTAssertFalse(gate.requireFeature(.bulkOperations, showPaywallIfBlocked: false))
    }

    func testRequireFeatureShowsPaywall() {
        let subService = SubscriptionService()
        subService.currentPlan = MockSubscriptionService.freePlan()
        let gate = FeatureGateService(subscriptionService: subService)

        XCTAssertFalse(gate.showPaywall)
        _ = gate.requireFeature(.exportReports, showPaywallIfBlocked: true)
        XCTAssertTrue(gate.showPaywall)
        XCTAssertEqual(gate.paywallTriggerFeature, .exportReports)
    }

    func testPremiumBypassesCheckLimit() async {
        let subService = SubscriptionService()
        subService.currentPlan = MockSubscriptionService.premiumPlan()
        let gate = FeatureGateService(subscriptionService: subService)

        let allowed = await gate.checkLimit(.pantryItems, householdId: UUID(), showPaywallIfBlocked: false)
        XCTAssertTrue(allowed)
    }

    // MARK: - SubscriptionFeature properties

    func testFeatureDisplayProperties() {
        for feature in SubscriptionFeature.allCases {
            XCTAssertFalse(feature.displayTitle.isEmpty)
            XCTAssertFalse(feature.systemImage.isEmpty)
            XCTAssertFalse(feature.paywallDescription.isEmpty)
        }
    }
}
