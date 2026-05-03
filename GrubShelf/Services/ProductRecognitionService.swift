import Foundation
import Vision
import UIKit

/// Result of product recognition from an image.
struct ProductRecognitionResult: Equatable {
    /// Best-effort item name (packaging OCR when readable, otherwise a humanized classifier label).
    let suggestedName: String
    /// Up to three candidate names ordered by confidence.
    let suggestions: [String]
    let category: String
    let confidence: Float
    /// `true` when at least one top-ranked Vision observation maps to a known food identifier.
    let isLikelyFood: Bool
}

/// Identifies grocery-related subjects from photos using on-device Vision (image classification + optional OCR).
enum ProductRecognitionService {
    static func recognize(from image: UIImage) async throws -> ProductRecognitionResult {
        guard let (cgImage, orientation) = cgImageAndOrientationForVision(from: image) else {
            throw ProductRecognitionError.invalidImage
        }

        let classification = try await classifyImage(cgImage: cgImage, orientation: orientation)
        let ocrText = await extractTextFromImage(cgImage: cgImage, orientation: orientation)

        let ocrTrimmed = ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ocrUsable = ocrTrimmed.count >= 3 && ocrTrimmed.count <= 80

        let suggestedName: String
        let suggestions: [String]
        if ocrUsable {
            suggestedName = ocrTrimmed
            suggestions = [ocrTrimmed] + topNameSuggestions(from: classification.identifiersForSuggestions, excluding: [ocrTrimmed], limit: 2)
        } else {
            suggestedName = ProductRecognitionGroceryMapper.displayName(fromVisionIdentifier: classification.identifierUsedForName)
            suggestions = topNameSuggestions(from: classification.identifiersForSuggestions, excluding: [], limit: 3)
        }

        return ProductRecognitionResult(
            suggestedName: suggestedName,
            suggestions: suggestions,
            category: classification.category,
            confidence: classification.confidence,
            isLikelyFood: classification.isLikelyFood
        )
    }

    /// Draws through UIKit so EXIF orientation is applied, then uses `.up` + a bounded size — fixes many Vision failures from camera/HEIC.
    private static func cgImageAndOrientationForVision(from image: UIImage) -> (CGImage, CGImagePropertyOrientation)? {
        normalizedBitmapCGImageUp(from: image)
    }

    private static func normalizedBitmapCGImageUp(from image: UIImage) -> (CGImage, CGImagePropertyOrientation)? {
        let maxPixel: CGFloat = 1024
        let iw = max(image.size.width * image.scale, 1)
        let ih = max(image.size.height * image.scale, 1)
        let scaleDown = min(1, maxPixel / max(iw, ih))
        let tw = max((iw * scaleDown).rounded(.down), 1)
        let th = max((ih * scaleDown).rounded(.down), 1)
        let target = CGSize(width: tw, height: th)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let cg = rendered.cgImage else { return nil }
        return (cg, .up)
    }

    private struct ClassificationPick {
        let category: String
        let confidence: Float
        let identifierUsedForName: String
        let identifiersForSuggestions: [String]
        let isLikelyFood: Bool
    }

    private static func classifyImage(cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> ClassificationPick {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassificationPick, Error>) in
            let once = ContinuationOnce(continuation)
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    once.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation], !observations.isEmpty else {
                    once.resume(returning: ClassificationPick(
                        category: "Other",
                        confidence: 0.35,
                        identifierUsedForName: "food",
                        identifiersForSuggestions: ["food"],
                        isLikelyFood: false
                    ))
                    return
                }

                let sorted = observations
                    .filter { $0.confidence > 0.005 }
                    .sorted { $0.confidence > $1.confidence }

                guard let top = sorted.first else {
                    once.resume(returning: ClassificationPick(
                        category: "Other",
                        confidence: 0.35,
                        identifierUsedForName: observations[0].identifier,
                        identifiersForSuggestions: observations.prefix(3).map(\.identifier),
                        isLikelyFood: false
                    ))
                    return
                }

                var bestCategory = ProductRecognitionGroceryMapper.pantryCategory(forVisionIdentifier: top.identifier)
                var bestConfidence = top.confidence
                var nameSourceId = top.identifier
                var foundFoodMatch = ProductRecognitionGroceryMapper.isKnownFoodIdentifier(top.identifier)

                for obs in sorted.prefix(12) {
                    if !foundFoodMatch && ProductRecognitionGroceryMapper.isKnownFoodIdentifier(obs.identifier) {
                        foundFoodMatch = true
                    }
                    let cat = ProductRecognitionGroceryMapper.pantryCategory(forVisionIdentifier: obs.identifier)
                    if cat != "Other" && bestCategory == "Other" {
                        bestCategory = cat
                        bestConfidence = obs.confidence
                        nameSourceId = obs.identifier
                    }
                }

                once.resume(returning: ClassificationPick(
                    category: bestCategory,
                    confidence: bestConfidence,
                    identifierUsedForName: nameSourceId,
                    identifiersForSuggestions: sorted.prefix(8).map(\.identifier),
                    isLikelyFood: foundFoodMatch
                ))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                once.resume(throwing: error)
            }
        }
    }

    private static func extractTextFromImage(cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sort by bounding-box area (largest first), break ties by vertical position (topmost).
                let ranked = observations.sorted { a, b in
                    let areaA = a.boundingBox.width * a.boundingBox.height
                    let areaB = b.boundingBox.width * b.boundingBox.height
                    if abs(areaA - areaB) > 0.01 { return areaA > areaB }
                    return a.boundingBox.origin.y > b.boundingBox.origin.y // higher Y = higher on screen in Vision coords
                }

                let noiseStarters = ["ingredients", "nutrition", "net wt", "best before",
                                     "best by", "use by", "exp", "calories", "serving",
                                     "storage", "contains", "allergen", "warning",
                                     "directions", "manufactured", "distributed"]

                let qualifying = ranked.compactMap { obs -> String? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.count >= 2 else { return nil }
                    // Skip number-heavy lines (>50% digits)
                    let digitCount = trimmed.filter(\.isNumber).count
                    if Double(digitCount) / Double(trimmed.count) > 0.5 { return nil }
                    // Skip packaging noise
                    let lower = trimmed.lowercased()
                    if noiseStarters.contains(where: { lower.hasPrefix($0) }) { return nil }
                    return String(trimmed.prefix(40))
                }

                guard !qualifying.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                var result = ""
                for block in qualifying.prefix(3) {
                    let candidate = result.isEmpty ? block : result + " " + block
                    if candidate.count > 80 { break }
                    result = candidate
                }
                continuation.resume(returning: result.isEmpty ? nil : result)
            }
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func topNameSuggestions(from identifiers: [String], excluding: [String], limit: Int) -> [String] {
        var seen = Set(excluding.map { $0.lowercased() })
        var names: [String] = []
        for id in identifiers {
            let candidate = ProductRecognitionGroceryMapper.displayName(fromVisionIdentifier: id)
            let key = candidate.lowercased()
            guard !seen.contains(key), candidate.count >= 2 else { continue }
            seen.insert(key)
            names.append(candidate)
            if names.count == limit { break }
        }
        if names.isEmpty {
            return [String(localized: "Grocery item")]
        }
        return names
    }

    /// Avoids double-resume if Vision invokes a completion more than once (defensive).
    private final class ContinuationOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var consumed = false
        private let continuation: CheckedContinuation<ClassificationPick, Error>

        init(_ continuation: CheckedContinuation<ClassificationPick, Error>) {
            self.continuation = continuation
        }

        func resume(returning value: ClassificationPick) {
            lock.lock()
            defer { lock.unlock() }
            guard !consumed else { return }
            consumed = true
            continuation.resume(returning: value)
        }

        func resume(throwing error: Error) {
            lock.lock()
            defer { lock.unlock() }
            guard !consumed else { return }
            consumed = true
            continuation.resume(throwing: error)
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

enum ProductRecognitionError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        }
    }
}
