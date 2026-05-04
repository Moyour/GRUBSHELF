import Foundation
import Testing
@testable import GrubShelf

private nonisolated final class TLSPublicKeyFixtureBundle: NSObject {}

struct TLSPublicKeyPinningTests {
    /// Snapshot DER for Let's Encrypt leaf `CN=openfoodfacts.org`; SPKI extractor should match openssl `dgst`.
    @Test func openFoodFactsSampleLeaf_spkiHashMatchesCapturedPin() throws {
        let bundle = Bundle(for: TLSPublicKeyFixtureBundle.self)
        guard
            let url = bundle.url(
                forResource: "OpenFoodFactsSampleLeaf",
                withExtension: "der",
                subdirectory: "Fixtures"
            )
            ?? bundle.url(forResource: "OpenFoodFactsSampleLeaf", withExtension: "der")
        else {
            Issue.record("Missing OpenFoodFactsSampleLeaf.der in test bundle.")
            return
        }

        let der = try Data(contentsOf: url)
        guard let hashed = TLSPublicKeyInfoExtractor.sha256SPKIBase64(fromDERCertificate: der) else {
            Issue.record("Expected SPKI hash for embedded certificate DER.")
            return
        }

        let expectedCapturedFromOpenSSL = "InERzfNB5stsbKvspsygSwmYD7pyI4t6mYen5DdHSTo="
        #expect(hashed == expectedCapturedFromOpenSSL)
    }
}
