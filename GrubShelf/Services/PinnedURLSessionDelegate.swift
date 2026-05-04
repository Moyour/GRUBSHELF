import CryptoKit
import Foundation
import Security

// MARK: - SPKI PKIX extraction from certificate DER

enum TLSPublicKeyInfoExtractor {
    /// Full TLV for PKIX `SubjectPublicKeyInfo` (SEQUENCE wrapping algorithm id + BIT STRING).
    static func pkixSubjectPublicKeyInfo(fromDERCertificate certificate: Data) -> Data? {
        guard certificate.first == 0x30 else { return nil }
        guard let certInner = TLV.sequenceInner(ofWholeDER: certificate) else { return nil }

        guard let tbscTLVWhole = TLV.splitTLVs(certInner).first,
              tbscTLVWhole.first == 0x30,
              let tbscInner = TLV.sequenceInner(ofWholeDER: tbscTLVWhole)
        else { return nil }

        for tlv in TLV.splitTLVs(tbscInner) where tlv.first == 0x30 {
            guard let inner = TLV.sequenceInner(ofWholeDER: tlv),
                  TLV.splitTLVs(inner).count == 2
            else {
                continue
            }
            let parts = TLV.splitTLVs(inner)
            if parts[0].first == 0x30, parts[1].first == 0x03 { return tlv }
        }
        return nil
    }

    static func sha256SPKIBase64(fromDERCertificate certificate: Data) -> String? {
        guard let spki = pkixSubjectPublicKeyInfo(fromDERCertificate: certificate) else { return nil }
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }
}

// MARK: - URLSession pinning (TLS public-key pins)

final class PinnedURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    nonisolated static let shared = PinnedURLSessionDelegate()

    /// SHA-256 of SPKI DER, Base64. Leaf plus Let's Encrypt issuer backup for `world.openfoodfacts.org`.
    private static let openFoodFactsSPKIPins: Set<String> = [
        "InERzfNB5stsbKvspsygSwmYD7pyI4t6mYen5DdHSTo=",
        "AlSQhgtJirc8ahLyekmtX+Iw+v46yPYRLJt9Cq1GlB0=",
    ]

    private static let hostToSPKIPins: [String: Set<String>] = [
        "world.openfoodfacts.org": openFoodFactsSPKIPins,
    ]

    private let hostnameToPins: [String: Set<String>] = PinnedURLSessionDelegate.hostToSPKIPins

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    private func evaluate(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()

        guard let pins = hostnameToPins[host], !pins.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if Self.trustMatchesSPKIBase64Pins(serverTrust: serverTrust, pins: pins) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private static func trustMatchesSPKIBase64Pins(serverTrust: SecTrust, pins: Set<String>) -> Bool {
        for certificate in certificateChain(for: serverTrust) {
            guard let der = SecCertificateCopyData(certificate) as Data?,
                  let hashed = TLSPublicKeyInfoExtractor.sha256SPKIBase64(fromDERCertificate: der),
                  pins.contains(hashed)
            else {
                continue
            }
            return true
        }
        return false
    }

    private static func certificateChain(for trust: SecTrust) -> [SecCertificate] {
        let count = SecTrustGetCertificateCount(trust)
        guard count > 0 else { return [] }

        return (0 ..< count).compactMap { index in
            SecTrustGetCertificateAtIndex(trust, index)
        }
    }
}

// MARK: - DER helpers

private enum TLV {
    static func sequenceInner(ofWholeDER tlv: Data) -> Data? {
        guard tlv.first == 0x30 else { return nil }
        var cursor = tlv.startIndex
        guard readByte(buffer: tlv, cursor: &cursor) != nil else { return nil }
        guard let innerLen = DERLength.decode(from: tlv, cursor: &cursor) else { return nil }
        guard tlv.distance(from: cursor, to: tlv.endIndex) >= innerLen else { return nil }
        let innerEnd = tlv.index(cursor, offsetBy: innerLen)
        guard innerEnd == tlv.endIndex else { return nil }
        return Data(tlv[cursor ..< innerEnd])
    }

    static func splitTLVs(_ payload: Data) -> [Data] {
        guard !payload.isEmpty else { return [] }
        var cursor = payload.startIndex
        var slices: [Data] = []

        while cursor < payload.endIndex {
            let start = cursor
            guard advanceWholeTLVEndExclusive(in: payload, cursor: &cursor) else { break }
            slices.append(payload.subdata(in: start ..< cursor))
        }
        return slices
    }

    private static func advanceWholeTLVEndExclusive(in buffer: Data, cursor: inout Data.Index) -> Bool {
        guard cursor < buffer.endIndex else { return false }

        guard readByte(buffer: buffer, cursor: &cursor) != nil /* tag */
        else { return false }

        guard let payloadLength = DERLength.decode(from: buffer, cursor: &cursor)
        else { return false }

        guard buffer.distance(from: cursor, to: buffer.endIndex) >= payloadLength else { return false }
        cursor = buffer.index(cursor, offsetBy: payloadLength)
        return true
    }

    private static func readByte(buffer: Data, cursor: inout Data.Index) -> UInt8? {
        guard cursor < buffer.endIndex else { return nil }
        let b = buffer[cursor]
        cursor = buffer.index(after: cursor)
        return b
    }
}

private enum DERLength {
    /// Decode BER length octets immediately after tag; advances `cursor` to first payload byte.
    static func decode(from buffer: Data, cursor: inout Data.Index) -> Int? {
        guard cursor < buffer.endIndex else { return nil }
        guard let head = TLV.readByteLike(buffer: buffer, cursor: &cursor) else { return nil }

        if (head & 0x80) == 0 {
            return Int(head)
        }

        let numOctets = Int(head & 0x7F)
        guard numOctets <= 8, buffer.distance(from: cursor, to: buffer.endIndex) >= numOctets else {
            return nil
        }

        var value = 0
        for _ in 0 ..< numOctets {
            guard let b = TLV.readByteLike(buffer: buffer, cursor: &cursor) else { return nil }
            value = (value << 8) | Int(b)
        }

        guard value >= 0 else { return nil }
        return value
    }
}

private extension TLV {
    /// Same behaviour as ``readByte`` but reusable from DERLength via extension scoping workaround.
    static func readByteLike(buffer: Data, cursor: inout Data.Index) -> UInt8? {
        guard cursor < buffer.endIndex else { return nil }
        let byte = buffer[cursor]
        cursor = buffer.index(after: cursor)
        return byte
    }
}
