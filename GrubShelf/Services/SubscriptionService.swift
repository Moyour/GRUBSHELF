import Foundation
import Observation
import os

@MainActor
@Observable
final class SubscriptionService {
    var currentPlan: SubscriptionPlan?
    var currentSubscription: UserSubscription?
    var isLoading = false
    var error: String?

    var isPremium: Bool { currentPlan?.isPremium ?? false }
    var isFree: Bool { currentPlan?.isFree ?? true }
    var features: FeatureLimits? { currentPlan?.features }

    private static let logger = Logger(subsystem: "com.grubshelf", category: "Subscription")
    private static let cacheKey = "com.grubshelf.subscriptionPlanCache"

    init() {
        loadFromCache()
    }

    // MARK: - Load subscription from backend

    func loadSubscription(householdId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Fire-and-forget: expire any lapsed subscriptions server-side.
        // This acts as a client-side fallback when pg_cron is unavailable.
        Task.detached(priority: .utility) {
            try? await SupabaseManager.shared.client
                .rpc("expire_subscriptions")
                .execute()
        }

        do {
            let response: [HouseholdSubscriptionResponse] = try await SupabaseManager.shared.client
                .rpc("get_household_subscription", params: ["p_household_id": householdId.uuidString])
                .execute()
                .value

            if let row = response.first {
                // Fetch full plan for caching
                let plans: [SubscriptionPlan] = try await SupabaseManager.shared.client
                    .from("subscription_plans")
                    .select()
                    .eq("name", value: row.planName)
                    .execute()
                    .value

                if let plan = plans.first {
                    currentPlan = plan
                    saveToCache(plan)
                }
            }

            // Fetch active subscription record
            let subs: [UserSubscription] = try await SupabaseManager.shared.client
                .from("user_subscriptions")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .in("status", values: ["active", "trialing"])
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            currentSubscription = subs.first
            error = nil
        } catch is CancellationError {
            // Cancelled — keep cached state
        } catch {
            Self.logger.error("Failed to load subscription: \(error.localizedDescription)")
            self.error = error.localizedDescription
            // Keep cached plan for offline
        }
    }

    // MARK: - Feature checks

    /// Local boolean check using cached plan (no network).
    func canUseFeature(_ feature: SubscriptionFeature) -> Bool {
        guard let features else { return true } // Permissive when no plan loaded
        switch feature {
        case .exportReports: return features.exportReports
        case .photoUploads: return features.photoUploads
        case .bulkOperations: return features.bulkOperations
        default: return true // Count-based features need server check
        }
    }

    /// Server-side limit check via RPC.
    func checkLimit(_ feature: SubscriptionFeature, householdId: UUID) async throws -> FeatureLimitCheck {
        let response: [FeatureLimitCheck] = try await SupabaseManager.shared.client
            .rpc("check_feature_limit", params: [
                "p_household_id": householdId.uuidString,
                "p_feature_key": feature.rawValue,
            ])
            .execute()
            .value

        guard let result = response.first else {
            // Default permissive
            return FeatureLimitCheck(canPerform: true, currentUsage: 0, limitValue: -1, isUnlimited: true)
        }
        return result
    }

    /// Increment a monthly usage counter.
    func incrementUsage(_ feature: SubscriptionFeature, householdId: UUID, userId: UUID) async {
        do {
            try await SupabaseManager.shared.client
                .rpc("increment_feature_usage", params: [
                    "p_household_id": householdId.uuidString,
                    "p_feature_key": feature.rawValue,
                    "p_user_id": userId.uuidString,
                ])
                .execute()
        } catch {
            Self.logger.warning("Failed to increment usage for \(feature.rawValue): \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription management

    func activatePremium(
        userId: UUID,
        householdId: UUID,
        externalSubscriptionId: String
    ) async throws {
        let _: [AnyJSON] = try await SupabaseManager.shared.client
            .rpc("create_subscription", params: [
                "p_user_id": userId.uuidString,
                "p_household_id": householdId.uuidString,
                "p_plan_name": "premium",
                "p_payment_provider": "apple_iap",
                "p_external_subscription_id": externalSubscriptionId,
            ])
            .execute()
            .value

        await loadSubscription(householdId: householdId)
    }

    func cancelSubscription(subscriptionId: UUID, immediately: Bool = false) async throws {
        let params = CancelSubscriptionParams(
            p_subscription_id: subscriptionId.uuidString,
            p_cancel_immediately: immediately
        )
        try await SupabaseManager.shared.client
            .rpc("cancel_subscription", params: params)
            .execute()
    }

    // MARK: - Offline cache

    private func saveToCache(_ plan: SubscriptionPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let plan = try? JSONDecoder().decode(SubscriptionPlan.self, from: data) else { return }
        currentPlan = plan
    }
}

// MARK: - RPC response type

private struct HouseholdSubscriptionResponse: Codable {
    let planName: String
    let displayName: String
    let features: FeatureLimits
    let isPremium: Bool
    let subscriptionStatus: String
    let currentPeriodEnd: Date?

    enum CodingKeys: String, CodingKey {
        case planName = "plan_name"
        case displayName = "display_name"
        case features
        case isPremium = "is_premium"
        case subscriptionStatus = "subscription_status"
        case currentPeriodEnd = "current_period_end"
    }
}

/// Params for cancel_subscription RPC (mixed String and Bool fields).
private struct CancelSubscriptionParams: Encodable {
    let p_subscription_id: String
    let p_cancel_immediately: Bool
}

/// Placeholder to satisfy the generic decode for RPCs returning UUIDs or arbitrary JSON.
private enum AnyJSON: Codable {
    case string(String)
    case number(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let n = try? container.decode(Double.self) { self = .number(n) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .null: try container.encodeNil()
        }
    }
}
