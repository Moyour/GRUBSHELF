import Foundation

struct UserSubscription: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let householdId: UUID
    let planId: UUID
    let status: SubscriptionStatus
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let paymentProvider: String?
    let externalSubscriptionId: String?

    var isExpired: Bool { currentPeriodEnd < .now }
    var isCancelled: Bool { status == .cancelled }
    var isActive: Bool { status == .active || status == .trialing }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case planId = "plan_id"
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case paymentProvider = "payment_provider"
        case externalSubscriptionId = "external_subscription_id"
    }
}

enum SubscriptionStatus: String, Codable, Sendable {
    case active
    case trialing
    case cancelled
    case expired
}
