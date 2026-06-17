import Foundation
import os
import Supabase
import UIKit
import UserNotifications

/// Registers for APNs and stores the device token in Supabase for server-side push.
final class PushNotificationService {
    static let shared = PushNotificationService()
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Push")

    private init() {}

    func registerIfAuthorized(application: UIApplication) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral else { return }
        await MainActor.run {
            application.registerForRemoteNotifications()
        }
    }

    func upsertDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        guard SupabaseManager.shared.isConfigured else { return }

        struct Params: Encodable {
            let p_token: String
            let p_platform: String
        }

        do {
            try await SupabaseManager.shared.client.rpc(
                "upsert_push_device_token",
                params: Params(p_token: token, p_platform: "ios")
            ).execute()
            Self.logger.info("Device token upserted successfully")
        } catch {
            Self.logger.error("Failed to upsert device token: \(error.localizedDescription, privacy: .public)")
        }
    }
}
