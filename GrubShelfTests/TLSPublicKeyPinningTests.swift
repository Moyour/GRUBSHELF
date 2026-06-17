import Foundation
import Testing
@testable import GrubShelf

struct TLSPublicKeyPinningTests {
    /// Snapshot DER for Let's Encrypt leaf `CN=openfoodfacts.org` (Base64 PEM-free); keeps tests self-contained — XcodeGen does not attach a Resources phase to the unit-test target.
    /// Regenerate when you replace the pinning fixture: same bytes as `GrubShelfTests/Fixtures/OpenFoodFactsSampleLeaf.der`.
    private static let openFoodFactsSampleLeafDERBase64 = """
MIIFEzCCA/ugAwIBAgISBtnUCwfsZWr01PJgp8bRD31jMA0GCSqGSIb3DQEBCwUAMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNSMTMwHhcNMjYwMjIxMDYxNTMzWhcNMjYwNTIyMDYxNTMyWjAcMRowGAYDVQQDExFvcGVuZm9vZGZhY3RzLm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANMeAqZqR396bxP5KbHfA0y/YvROO6H6XvILuC66SixvcqUYKW8WjNvKMicLXHFVDCCdmjBfhmQfq3T6Zs9LBLlpqtaVUAiwgnisXsZskgeEHisY4LYjEqx6o5TJJxXeoZJpvCWuCKB4RMA802WiiygQ2zFyr2QHln6AYrcQWJa/35NZlanizZ27g+nl/NXL7CDXBmNjwHkrY7U4PC40AFRIrP70vaEf/yHEjEtCc2ZAvnUn2VAxEyb3QTMsD1sezWxzgQxuSzqY8M8o0nwcnwNSKyQFEaIk7RlzBY30bvCZI95W3SN6/2xOVcpXgrlfcL/QuZeGtj7GsxzC0fRD5EsCAwEAAaOCAjYwggIyMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAKBggrBgEFBQcDATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBQgIPrA5WgwdVEB6+Tbcdl/QtN1TDAfBgNVHSMEGDAWgBTnq58PLDOgU9NeT3jIsoQOO9aSMzAzBggrBgEFBQcBAQQnMCUwIwYIKwYBBQUHMAKGF2h0dHA6Ly9yMTMuaS5sZW5jci5vcmcvMDEGA1UdEQQqMCiCEyoub3BlbmZvb2RmYWN0cy5vcmeCEW9wZW5mb29kZmFjdHMub3JnMBMGA1UdIAQMMAowCAYGZ4EMAQIBMC8GA1UdHwQoMCYwJKAioCCGHmh0dHA6Ly9yMTMuYy5sZW5jci5vcmcvMTAwLmNybDCCAQ0GCisGAQQB1nkCBAIEgf4EgfsA+QB+AOMjjfKNoojgquCs8PqQyYXwtr/10qUnsAH8HERYxLboAAABnH8MYIMACAAABQAzQclVBAMARzBFAiBvNlGeO/JUk0JRvNNUpx+mTMugzYeHtwh3CaRwMVIQxgIhAPfP766s07IoVUEhi1Ksey1kclGUaQJjB5js58w4cTAwAHcAlpdkv1VYl633Q4doNwhCd+nwOtX2pPM2bkakPw/KqcYAAAGcfwxvvgAABAMASDBGAiEA4kfWxhYUNmidhF7Q/epAiUGIyjLC3Z7VU62jd9JeBMQCIQDW2oZP/d3u2HLXqhBdi2HYOH1O/fTWOH0HQ/GQex4UsTANBgkqhkiG9w0BAQsFAAOCAQEAbrVBFJMP8teOH9N6MuqVCAhW/ge1l1aUwiB6b1xRH1CzbNe1DG6VhkX3OaCM7Fj6RiRiKTsxj007z6OOs9vB5jAD6aXZ9TIkW3e69BAcJ0rQy58kFT4O/xfQ6qB2XOwKArL5yn6yRodCAmVkjuzgMt1dE2EHO4PIqB/963g7I0TxAsoaWypBtornKYes6xDW9dnVeNzp56dfR0TrEUBWjVDUyAvYncWQByqvVJDWvsY6wzOXzc2rIml57cgfJdA1xuDm5VSykgidODAxirMy/c6JtTsA0qYNf1fBNVCcFykusjK+GIGknfx6Ww2yT2ch92wJXIBScLOlynsS7JxTOg==
"""

    /// SPKI extractor should match OpenSSL (`openssl dgst -sha256 -binary | openssl base64`) on embedded leaf.
    @Test func openFoodFactsSampleLeaf_spkiHashMatchesCapturedPin() throws {
        var b64 = Self.openFoodFactsSampleLeafDERBase64
        b64.removeAll { $0.isWhitespace }
        guard let der = Data(base64Encoded: b64) else {
            Issue.record("Expected valid Base64 certificate DER fixture.")
            return
        }

        guard let hashed = TLSPublicKeyInfoExtractor.sha256SPKIBase64(fromDERCertificate: der) else {
            Issue.record("Expected SPKI hash for embedded certificate DER.")
            return
        }

        #expect(hashed == "InERzfNB5stsbKvspsygSwmYD7pyI4t6mYen5DdHSTo=")
    }
}
