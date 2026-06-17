import Foundation

struct SubscriptionPlan: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let features: FeatureLimits
    let priceMonthlyCents: Int
    let priceYearlyCents: Int
    let isActive: Bool

    var isPremium: Bool { name == "premium" }
    var isFree: Bool { name == "free" }

    var monthlyPriceFormatted: String {
        let dollars = Double(priceMonthlyCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var yearlyPriceFormatted: String {
        let dollars = Double(priceYearlyCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var yearlyMonthlyEquivalentFormatted: String {
        let monthly = Double(priceYearlyCents) / 12.0 / 100.0
        return String(format: "$%.2f", monthly)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case features
        case priceMonthlyCents = "price_monthly_cents"
        case priceYearlyCents = "price_yearly_cents"
        case isActive = "is_active"
    }
}

/// Represents all feature limits for a subscription plan.
struct FeatureLimits: Codable, Equatable, Sendable {
    let householdMembers: FeatureLimitValue
    let pantryItems: FeatureLimitValue
    let shoppingLists: FeatureLimitValue
    let barcodeScansPerMonth: FeatureLimitValue
    let analyticsDays: FeatureLimitValue
    let exportReports: Bool
    let photoUploads: Bool
    let bulkOperations: Bool

    enum CodingKeys: String, CodingKey {
        case householdMembers = "household_members"
        case pantryItems = "pantry_items"
        case shoppingLists = "shopping_lists"
        case barcodeScansPerMonth = "barcode_scans_per_month"
        case analyticsDays = "analytics_days"
        case exportReports = "export_reports"
        case photoUploads = "photo_uploads"
        case bulkOperations = "bulk_operations"
    }
}

/// A feature limit that can be a numeric cap or unlimited (-1).
enum FeatureLimitValue: Codable, Equatable, Sendable {
    case limited(Int)
    case unlimited

    var numericLimit: Int? {
        switch self {
        case .limited(let n): return n
        case .unlimited: return nil
        }
    }

    var isUnlimited: Bool {
        if case .unlimited = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        self = value == -1 ? .unlimited : .limited(value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .limited(let n): try container.encode(n)
        case .unlimited: try container.encode(-1)
        }
    }
}
