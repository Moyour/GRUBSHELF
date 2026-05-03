import Foundation
import Testing
@testable import GrubShelf

struct PasswordResetCallbackURLTests {
    @Test func matches_acceptsConfiguredResetCallback() {
        let url = URL(string: "\(PasswordResetCallbackURL.scheme)://\(PasswordResetCallbackURL.host)?code=test")!
        #expect(PasswordResetCallbackURL.matches(url))
    }

    @Test func matches_rejectsOtherSchemesAndHosts() {
        #expect(!PasswordResetCallbackURL.matches(URL(string: "https://example.com")!))
        #expect(!PasswordResetCallbackURL.matches(URL(string: "grubshelf://oauth")!))
        #expect(!PasswordResetCallbackURL.matches(URL(string: "other://reset-password")!))
    }

    @Test func redirectURL_schemeAndHostAlignWithMatchers() {
        let u = PasswordResetCallbackURL.redirectURL
        #expect(u.scheme?.caseInsensitiveCompare(PasswordResetCallbackURL.scheme) == .orderedSame)
        #expect(u.host?.caseInsensitiveCompare(PasswordResetCallbackURL.host) == .orderedSame)
    }

    @Test func matches_schemeAndHost_areCaseInsensitive() {
        let u = URL(string: "GRUBSHELF://RESET-PASSWORD")!
        #expect(PasswordResetCallbackURL.matches(u))
    }
}
