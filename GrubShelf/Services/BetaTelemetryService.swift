import Foundation
import Supabase
import os

/// Lightweight beta telemetry that logs key user milestones to the existing
/// `audit_logs` table via the `log_audit_event` RPC. Events are fire-and-forget;
/// failures are logged but never block the user.
@MainActor
final class BetaTelemetryService {
    static let shared = BetaTelemetryService()

    private static let logger = Logger(subsystem: "com.grubshelf", category: "BetaTelemetry")

    private init() {}

    // MARK: - Event keys (stored in UserDefaults to avoid duplicate logging)

    private enum EventKey: String {
        case onboardingCompleted = "beta.onboarding_completed"
        case firstListCreated = "beta.first_list_created"
        case firstTransfer = "beta.first_transfer"
        case day7Open = "beta.day_7_open"
    }

    // MARK: - Public API

    func logOnboardingCompleted() {
        logOnce(.onboardingCompleted, action: "onboarding_completed")
    }

    func logFirstListCreated() {
        logOnce(.firstListCreated, action: "first_list_created")
    }

    func logFirstTransfer() {
        logOnce(.firstTransfer, action: "first_transfer")
    }

    func logDay7OpenIfApplicable(accountCreatedAt: Date?) {
        guard let created = accountCreatedAt else { return }
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: created, to: .now).day ?? 0
        guard daysSinceCreation >= 7 else { return }
        logOnce(.day7Open, action: "day_7_open", metadata: "{\"days_since_creation\": \(daysSinceCreation)}")
    }

    // MARK: - Internal

    private func logOnce(_ key: EventKey, action: String, metadata: String = "{}") {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key.rawValue) else { return }
        defaults.set(true, forKey: key.rawValue)

        Task {
            do {
                try await SupabaseManager.shared.client
                    .rpc("log_audit_event", params: [
                        "p_action": action,
                        "p_target_entity": "beta_telemetry",
                        "p_metadata": metadata,
                    ])
                    .execute()
                Self.logger.info("Beta telemetry logged: \(action, privacy: .public)")
            } catch {
                Self.logger.error("Beta telemetry failed (\(action, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
