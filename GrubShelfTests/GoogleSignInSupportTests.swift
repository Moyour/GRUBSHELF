import GoogleSignIn
import Testing
@testable import GrubShelf

struct GoogleSignInSupportTests {
    @Test func googleOAuthConfigBuildsGIDConfigurationWithServerClientID() {
        let config = GoogleOAuthConfig(
            iosClientID: "111-ios.apps.googleusercontent.com",
            webClientID: "222-web.apps.googleusercontent.com"
        )
        let gid = config.makeGIDConfiguration()
        #expect(gid.clientID == "111-ios.apps.googleusercontent.com")
        #expect(gid.serverClientID == "222-web.apps.googleusercontent.com")
    }

    @Test func reversedClientIDURLScheme() {
        let scheme = GoogleSignInSupport.reversedClientIDURLScheme(
            from: "313042839436-tp2chd8q21dv9ics36i5fpff58d4floc.apps.googleusercontent.com"
        )
        #expect(scheme == "com.googleusercontent.apps.313042839436-tp2chd8q21dv9ics36i5fpff58d4floc")
    }

    @Test func reversedClientIDURLSchemeRejectsInvalidInput() {
        #expect(GoogleSignInSupport.reversedClientIDURLScheme(from: "not-a-google-client") == nil)
        #expect(GoogleSignInSupport.reversedClientIDURLScheme(from: "") == nil)
    }
}
