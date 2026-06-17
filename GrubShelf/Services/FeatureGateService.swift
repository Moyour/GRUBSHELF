import Foundation
import Observation
import os

@MainActor
@Observable
final class FeatureGateService {
    var showPaywall = false
    var paywallTriggerFeature: SubscriptionFeature?
    var paywallLimitInfo: FeatureLimitCheck?

    private let subscriptionService: SubscriptionService
    private static let logger = Logger(subsystem: "com.grubshelf", category: "FeatureGate")

    init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
    }

    // MARK: - Boolean gate (export, photos, bulk)

    /// Returns `true` if the feature is available. If blocked and `showPaywallIfBlocked`
    /// is true, presents the paywall sheet.
    @discardableResult
    func requireFeature(_ feature: SubscriptionFeature, showPaywallIfBlocked: Bool = true) -> Bool {
        let allowed = subscriptionService.canUseFeature(feature)
        if !allowed && showPaywallIfBlocked {
            paywallTriggerFeature = feature
            paywallLimitInfo = nil
            showPaywall = true
        }
        return allowed
    }

    // MARK: - Metered / count-based limit (items, lists, members, scans)

    /// Returns `true` if the action is allowed. On network error, returns `true` (permissive offline).
    func checkLimit(
        _ feature: SubscriptionFeature,
        householdId: UUID,
        showPaywallIfBlocked: Bool = true
    ) async -> Bool {
        // Premium users bypass all limits
        if subscriptionService.isPremium { return true }

        do {
            let check = try await subscriptionService.checkLimit(feature, householdId: householdId)
            if !check.canPerform && showPaywallIfBlocked {
                paywallTriggerFeature = feature
                paywallLimitInfo = check
                showPaywall = true
            }
            return check.canPerform
        } catch {
            // Permissive on network error
            Self.logger.warning("Limit check failed for \(feature.rawValue), allowing: \(error.localizedDescription)")
            return true
        }
    }

    // MARK: - Usage recording

    /// Records usage after a successful action (e.g., barcode scan).
    func recordUsage(_ feature: SubscriptionFeature, householdId: UUID, userId: UUID) async {
        await subscriptionService.incrementUsage(feature, householdId: householdId, userId: userId)
    }

    // MARK: - Convenience

    /// Fetches the current limit info for a feature (used for usage banners).
    func currentLimitInfo(_ feature: SubscriptionFeature, householdId: UUID) async -> FeatureLimitCheck? {
        if subscriptionService.isPremium { return nil }
        return try? await subscriptionService.checkLimit(feature, householdId: householdId)
    }
}
