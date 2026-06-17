import Foundation
@testable import GrubShelf

/// Mock subscription service for unit testing feature gates.
@MainActor
final class MockSubscriptionService {
    var mockPlan: SubscriptionPlan?
    var mockLimitCheckResult: FeatureLimitCheck?
    var incrementUsageCalled = false
    var activatePremiumCalled = false

    var isPremium: Bool { mockPlan?.isPremium ?? false }
    var isFree: Bool { mockPlan?.isFree ?? true }
    var features: FeatureLimits? { mockPlan?.features }

    func canUseFeature(_ feature: SubscriptionFeature) -> Bool {
        guard let features else { return true }
        switch feature {
        case .exportReports: return features.exportReports
        case .photoUploads: return features.photoUploads
        case .bulkOperations: return features.bulkOperations
        default: return true
        }
    }

    func checkLimit(_ feature: SubscriptionFeature, householdId: UUID) async throws -> FeatureLimitCheck {
        guard let result = mockLimitCheckResult else {
            return FeatureLimitCheck(canPerform: true, currentUsage: 0, limitValue: -1, isUnlimited: true)
        }
        return result
    }

    func incrementUsage(_ feature: SubscriptionFeature, householdId: UUID, userId: UUID) async {
        incrementUsageCalled = true
    }

    // MARK: - Helpers

    static func freePlan() -> SubscriptionPlan {
        SubscriptionPlan(
            id: UUID(),
            name: "free",
            displayName: "Free",
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
            priceMonthlyCents: 0,
            priceYearlyCents: 0,
            isActive: true
        )
    }

    static func premiumPlan() -> SubscriptionPlan {
        SubscriptionPlan(
            id: UUID(),
            name: "premium",
            displayName: "Premium",
            features: FeatureLimits(
                householdMembers: .unlimited,
                pantryItems: .unlimited,
                shoppingLists: .unlimited,
                barcodeScansPerMonth: .unlimited,
                analyticsDays: .unlimited,
                exportReports: true,
                photoUploads: true,
                bulkOperations: true
            ),
            priceMonthlyCents: 499,
            priceYearlyCents: 5499,
            isActive: true
        )
    }
}
