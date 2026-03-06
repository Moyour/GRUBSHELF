import Foundation
import os

struct OpenFoodFactsProduct: Sendable {
    let name: String
    let category: String
    let quantity: String?
    let barcode: String
}

enum BarcodeError: LocalizedError {
    case invalidBarcode
    case networkError(Error)
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Invalid barcode format"
        case .networkError:
            return "Network error — check your connection and try again"
        case .productNotFound:
            return "Product not found for this barcode"
        }
    }
}

struct OpenFoodFactsService {
    private static let logger = Logger(subsystem: "com.foodpan", category: "BarcodeScanner")

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    static func lookup(barcode: String) async throws -> OpenFoodFactsProduct? {
        // Validate barcode: only digits, 8-14 characters (covers EAN-8, EAN-13, UPC-A, UPC-E expanded)
        let sanitized = barcode.trimmingCharacters(in: .whitespaces)
        guard !sanitized.isEmpty,
              sanitized.allSatisfy(\.isNumber),
              (8...14).contains(sanitized.count) else {
            throw BarcodeError.invalidBarcode
        }

        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(sanitized).json?fields=product_name,categories_tags,quantity"
        guard let url = URL(string: urlString) else {
            throw BarcodeError.invalidBarcode
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            logger.error("Barcode lookup network error: \(error.localizedDescription)")
            throw BarcodeError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BarcodeError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            logger.warning("Barcode lookup HTTP \(httpResponse.statusCode) for \(sanitized)")
            if httpResponse.statusCode >= 500 {
                throw BarcodeError.networkError(URLError(.badServerResponse))
            }
            throw BarcodeError.productNotFound
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = json?["status"] as? Int, status == 1,
              let product = json?["product"] as? [String: Any] else {
            throw BarcodeError.productNotFound
        }

        let name = product["product_name"] as? String ?? ""
        guard !name.isEmpty else { throw BarcodeError.productNotFound }

        let categoriesTags = product["categories_tags"] as? [String] ?? []
        let category = mapCategory(from: categoriesTags)
        let quantity = product["quantity"] as? String

        logger.info("Barcode \(sanitized) resolved to: \(name) [\(category)]")

        return OpenFoodFactsProduct(
            name: name,
            category: category,
            quantity: quantity,
            barcode: sanitized
        )
    }

    private static func mapCategory(from tags: [String]) -> String {
        let tagString = tags.joined(separator: " ").lowercased()

        if tagString.contains("fruit") { return "Fruits" }
        if tagString.contains("vegetable") { return "Vegetables" }
        if tagString.contains("dairy") || tagString.contains("milk") || tagString.contains("cheese") || tagString.contains("yogurt") { return "Dairy" }
        if tagString.contains("meat") || tagString.contains("poultry") || tagString.contains("beef") || tagString.contains("pork") || tagString.contains("chicken") { return "Meat" }
        if tagString.contains("fish") || tagString.contains("seafood") { return "Seafood" }
        if tagString.contains("grain") || tagString.contains("cereal") || tagString.contains("pasta") || tagString.contains("rice") || tagString.contains("bread") { return "Grains" }
        if tagString.contains("snack") || tagString.contains("chip") || tagString.contains("cookie") || tagString.contains("candy") { return "Snacks" }
        if tagString.contains("beverage") || tagString.contains("drink") || tagString.contains("juice") || tagString.contains("water") || tagString.contains("soda") { return "Beverages" }
        if tagString.contains("frozen") { return "Frozen" }
        if tagString.contains("sauce") || tagString.contains("condiment") || tagString.contains("spice") || tagString.contains("seasoning") { return "Condiments" }
        if tagString.contains("bakery") || tagString.contains("baked") { return "Bakery" }
        if tagString.contains("canned") || tagString.contains("preserved") { return "Canned" }

        return "Other"
    }
}
