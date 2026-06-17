import Foundation

struct FeatureUsage: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let householdId: UUID
    let featureKey: String
    let usageCount: Int
    let periodStart: Date
    let periodEnd: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case featureKey = "feature_key"
        case usageCount = "usage_count"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

/// Result from the `check_feature_limit` RPC.
struct FeatureLimitCheck: Codable, Equatable, Sendable {
    let canPerform: Bool
    let currentUsage: Int
    let limitValue: Int
    let isUnlimited: Bool

    /// Percentage of limit used (0.0–1.0). Returns 0 if unlimited.
    var usagePercentage: Double {
        guard !isUnlimited, limitValue > 0 else { return 0 }
        return min(Double(currentUsage) / Double(limitValue), 1.0)
    }

    /// True when usage is at or above 80% of the limit.
    var isNearLimit: Bool {
        !isUnlimited && usagePercentage >= 0.8
    }

    var remainingCount: Int? {
        guard !isUnlimited else { return nil }
        return max(limitValue - currentUsage, 0)
    }

    enum CodingKeys: String, CodingKey {
        case canPerform = "can_perform"
        case currentUsage = "current_usage"
        case limitValue = "limit_value"
        case isUnlimited = "is_unlimited"
    }
}
