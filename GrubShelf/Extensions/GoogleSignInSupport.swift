import GoogleSignIn
import os
import UIKit

/// OAuth client IDs from `Config.plist` for native Google Sign-In + Supabase.
struct GoogleOAuthConfig: Equatable {
    let iosClientID: String
    /// Web application client ID — used as `serverClientID` so the id_token `aud` matches Supabase.
    let webClientID: String

    static func load(from bundle: Bundle = .main) -> GoogleOAuthConfig? {
        guard let path = bundle.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path)
        else { return nil }

        guard let iosClientID = validClientID(config["GOOGLE_CLIENT_ID"]),
              let webClientID = validClientID(config["GOOGLE_WEB_CLIENT_ID"])
        else { return nil }

        return GoogleOAuthConfig(iosClientID: iosClientID, webClientID: webClientID)
    }

    /// Human-readable reason when `load()` fails (for UI / logs).
    static func loadFailureReason(from bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path)
        else {
            return "Config.plist was not found in the app bundle. Save the file and rebuild."
        }
        if validClientID(config["GOOGLE_CLIENT_ID"]) == nil {
            return "GOOGLE_CLIENT_ID is missing or still a placeholder in Config.plist."
        }
        if validClientID(config["GOOGLE_WEB_CLIENT_ID"]) == nil {
            return "GOOGLE_WEB_CLIENT_ID is missing or still a placeholder (YOUR_…). Save Config.plist and rebuild."
        }
        return "Google OAuth keys in Config.plist could not be read."
    }

    private static func validClientID(_ value: Any?) -> String? {
        guard let id = value as? String,
              !id.isEmpty,
              !id.contains("YOUR_"),
              id.hasSuffix(".apps.googleusercontent.com")
        else { return nil }
        return id
    }

    func makeGIDConfiguration() -> GIDConfiguration {
        GIDConfiguration(clientID: iosClientID, serverClientID: webClientID)
    }
}

/// Logs where Google Sign-In branding comes from (Xcode console, filter: `GoogleSignIn`).
enum GoogleSignInTrace {
    private static let logger = Logger(subsystem: "com.grubshelf", category: "GoogleSignIn")

    static func logStartupConfiguration(oauth: GoogleOAuthConfig) {
        let info = Bundle.main.infoDictionary
        let display = info?["CFBundleDisplayName"] as? String ?? "(nil)"
        let name = info?["CFBundleName"] as? String ?? "(nil)"
        let bundleId = Bundle.main.bundleIdentifier ?? "(nil)"
        let projectNumber = oauth.iosClientID.split(separator: "-").first.map(String.init) ?? "?"
        logger.info(
            """
            Google Sign-In configured — bundleDisplayName=\(display, privacy: .public) \
            bundleName=\(name, privacy: .public) bundleId=\(bundleId, privacy: .public) \
            googleCloudProjectNumber=\(projectNumber, privacy: .public) \
            iosClient=\(clientLabel(oauth.iosClientID), privacy: .public) \
            webClient(serverClientID)=\(clientLabel(oauth.webClientID), privacy: .public). \
            The name on Google's sign-in sheet is from OAuth consent screen in that Google Cloud project, not Config.plist.
            """
        )
    }

    /// After sign-in, log token audience (which OAuth client Google issued the token for).
    static func logIDTokenClaims(_ idToken: String) {
        guard let payload = Self.jwtPayload(idToken) else {
            logger.warning("Could not decode Google id_token payload for trace")
            return
        }
        let aud = payload["aud"].map { "\($0)" } ?? "?"
        let azp = payload["azp"].map { "\($0)" } ?? "?"
        logger.info(
            "Google id_token aud=\(aud, privacy: .public) azp=\(azp, privacy: .public) — aud should match GOOGLE_WEB_CLIENT_ID"
        )
    }

    private static func clientLabel(_ clientID: String) -> String {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return clientID }
        return String(clientID.dropLast(suffix.count))
    }

    private static func jwtPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padLength)
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}

enum GoogleSignInSupport {
    @discardableResult
    static func configureFromAppConfig() -> Bool {
        guard let oauth = GoogleOAuthConfig.load() else {
            GIDSignIn.sharedInstance.configuration = nil
            Logger(subsystem: "com.grubshelf", category: "GoogleSignIn")
                .error("Google OAuth config failed: \(GoogleOAuthConfig.loadFailureReason(), privacy: .public)")
            return false
        }
        GIDSignIn.sharedInstance.configuration = oauth.makeGIDConfiguration()
        GoogleSignInTrace.logStartupConfiguration(oauth: oauth)
        return true
    }

    static var configurationErrorMessage: String {
        GoogleOAuthConfig.loadFailureReason()
    }
    /// Reverses an iOS OAuth client ID for `CFBundleURLSchemes`.
    /// e.g. `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`
    static func reversedClientIDURLScheme(from clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return nil }
        let prefix = String(clientID.dropLast(suffix.count))
        guard !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix)"
    }

    /// View controller Google Sign-In should present from (topmost in the key window).
    @MainActor
    static func viewControllerForSignIn() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            return nil
        }
        return topmostViewController(from: root)
    }

    @MainActor
    private static func topmostViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topmostViewController(from: presented)
        }
        if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
            return topmostViewController(from: visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topmostViewController(from: selected)
        }
        return controller
    }
}
