import SwiftUI

// MARK: - SubscriptionService

private struct SubscriptionServiceKey: EnvironmentKey {
    static let defaultValue: SubscriptionService? = nil
}

extension EnvironmentValues {
    var subscriptionService: SubscriptionService? {
        get { self[SubscriptionServiceKey.self] }
        set { self[SubscriptionServiceKey.self] = newValue }
    }
}

// MARK: - FeatureGateService

private struct FeatureGateServiceKey: EnvironmentKey {
    static let defaultValue: FeatureGateService? = nil
}

extension EnvironmentValues {
    var featureGateService: FeatureGateService? {
        get { self[FeatureGateServiceKey.self] }
        set { self[FeatureGateServiceKey.self] = newValue }
    }
}

// MARK: - StoreKitService

private struct StoreKitServiceKey: EnvironmentKey {
    static let defaultValue: StoreKitService? = nil
}

extension EnvironmentValues {
    var storeKitService: StoreKitService? {
        get { self[StoreKitServiceKey.self] }
        set { self[StoreKitServiceKey.self] = newValue }
    }
}
