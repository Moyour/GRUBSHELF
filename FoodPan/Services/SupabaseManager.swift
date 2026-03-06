import Foundation
import os
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    let isConfigured: Bool

    private static let logger = Logger(subsystem: "com.foodpan", category: "SupabaseManager")

    private init() {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let urlString = config["SUPABASE_URL"] as? String,
           let anonKey = config["SUPABASE_ANON_KEY"] as? String,
           let url = URL(string: urlString),
           !urlString.hasPrefix("YOUR_") {
            client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: anonKey,
                options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
            )
            isConfigured = true
        } else {
            Self.logger.warning("Config.plist missing or contains placeholder values. Using unconfigured client.")
            client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder"
            )
            isConfigured = false
        }
    }
}
