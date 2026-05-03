import Foundation

/// Deep link target for Supabase password recovery (`redirect_to` must match Supabase Auth redirect allow list).
enum PasswordResetCallbackURL {
    static let scheme = "grubshelf"
    static let host = "reset-password"

    static var redirectURL: URL {
        URL(string: "\(scheme)://\(host)")!
    }

    static func matches(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame
            && url.host?.caseInsensitiveCompare(host) == .orderedSame
    }
}
