import Foundation
import Vision
import UIKit

/// Extracts text from a receipt image using Apple Vision OCR.
enum ReceiptOCRService {
    private static let receiptCustomWords = [
        "SUBTOTAL", "TOTAL", "TAX", "VAT", "CASH", "CARD", "CHANGE",
        "GRAND TOTAL", "BALANCE", "AMOUNT DUE", "RECEIPT", "THANK YOU",
        "DISCOUNT", "COUPON", "REFUND", "EXCHANGE"
    ]

    /// Performs OCR on the given image and returns text lines with approximate vertical positions.
    /// - Parameter image: Receipt image (UIImage or CGImage)
    /// - Returns: Array of (text, normalizedY) where Y is 0–1 from top to bottom for ordering
    static func extractText(from image: UIImage) async throws -> [(text: String, y: CGFloat)] {
        guard let cgImage = image.cgImage else {
            throw ReceiptOCRError.invalidImage
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = observations.compactMap { obs -> (String, CGFloat)? in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    let y = obs.boundingBox.midY
                    return (top.string, y)
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.customWords = receiptCustomWords
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum ReceiptOCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        }
    }
}
