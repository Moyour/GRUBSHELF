import Foundation
import os

struct OpenFoodFactsProduct: Sendable {
    let name: String
    let category: String
    let quantity: String?
    let barcode: String
    /// Best string to search the grocery catalog (prefers generic product description over brand-heavy titles).
    let catalogSearchQuery: String
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
    private static let logger = Logger(subsystem: "com.grubshelf", category: "BarcodeScanner")

    private static let lookupRateLimiter = RateLimiter(maxAttempts: 30, window: 60)

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: config, delegate: PinnedURLSessionDelegate.shared, delegateQueue: nil)
    }()

    static func lookup(barcode: String) async throws -> OpenFoodFactsProduct {
        let digits = barcode.trimmingCharacters(in: .whitespacesAndNewlines).filter(\.isNumber)
        guard (8...14).contains(digits.count) else {
            throw BarcodeError.invalidBarcode
        }

        try await lookupRateLimiter.attempt()

        // Try the barcode as-is first
        if let product = try await fetchProduct(barcode: digits) {
            return product
        }

        // If 12-digit UPC-A, also try as EAN-13 (prepend leading "0")
        if digits.count == 12 {
            logger.debug("UPC-A \(digits) not found, trying as EAN-13 with leading zero")
            try await lookupRateLimiter.attempt()
            if let product = try await fetchProduct(barcode: "0" + digits) {
                return product
            }
        }

        // If 13-digit EAN-13 starting with "0", try as 12-digit UPC-A
        if digits.count == 13, digits.hasPrefix("0") {
            let upcA = String(digits.dropFirst())
            logger.debug("EAN-13 \(digits) not found, trying as UPC-A \(upcA)")
            try await lookupRateLimiter.attempt()
            if let product = try await fetchProduct(barcode: upcA) {
                return product
            }
        }

        throw BarcodeError.productNotFound
    }

    private static func fetchProduct(barcode: String) async throws -> OpenFoodFactsProduct? {
        if let p = try await fetchProductJSON(barcode: barcode, apiPath: "/api/v2/product/\(barcode).json", useFields: true) {
            return p
        }
        // v0 often succeeds when v2 `fields=` responses omit data we need for some products.
        try await lookupRateLimiter.attempt()
        return try await fetchProductJSON(barcode: barcode, apiPath: "/api/v0/product/\(barcode).json", useFields: false)
    }

    private static func fetchProductJSON(barcode: String, apiPath: String, useFields: Bool) async throws -> OpenFoodFactsProduct? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = apiPath
        if useFields {
            components.queryItems = [
                URLQueryItem(
                    name: "fields",
                    value: "product_name,product_name_en,generic_name,abbreviated_product_name,brands,brands_tags,categories_tags,quantity"
                )
            ]
        }
        guard let url = components.url else {
            return nil
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
            logger.warning("Barcode lookup HTTP \(httpResponse.statusCode) for \(barcode) path \(apiPath)")
            if httpResponse.statusCode >= 500 {
                throw BarcodeError.networkError(URLError(.badServerResponse))
            }
            return nil
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard productFound(in: json), let product = json?["product"] as? [String: Any] else {
            return nil
        }

        let naturalName = OpenFoodFactsProductNameResolver.resolvedName(from: product)
        let resolvedName = OpenFoodFactsProductNameResolver.displayName(from: product, barcode: barcode)
        let searchQuery = Self.catalogSearchQuery(from: product, fallbackDisplayName: resolvedName)

        let categoriesTags = product["categories_tags"] as? [String] ?? []
        let category = mapCategory(from: categoriesTags)
        let quantity = product["quantity"] as? String

        if naturalName == nil {
            logger.warning("Barcode \(barcode): product found but no title fields — using placeholder")
        } else {
            logger.debug("Barcode \(barcode) resolved to: \(resolvedName) [\(category)]")
        }

        return OpenFoodFactsProduct(
            name: resolvedName,
            category: category,
            quantity: quantity,
            barcode: barcode,
            catalogSearchQuery: searchQuery
        )
    }

    private static func catalogSearchQuery(from product: [String: Any], fallbackDisplayName: String) -> String {
        let generic = (product["generic_name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if generic.count >= 3 {
            return String(generic.prefix(120))
        }
        let trimmed = fallbackDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(120))
    }

    /// Open Food Facts may encode `status` as Int, Double, or Bool depending on endpoint/version.
    private static func productFound(in json: [String: Any]?) -> Bool {
        guard let json else { return false }
        if let i = json["status"] as? Int { return i == 1 }
        if let d = json["status"] as? Double { return Int(d) == 1 }
        if let b = json["status"] as? Bool { return b }
        return false
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

// MARK: - Product title parsing

enum OpenFoodFactsProductNameResolver {
    static func resolvedName(from product: [String: Any]) -> String? {
        let directKeys = [
            "product_name", "product_name_en", "generic_name", "abbreviated_product_name",
            "product_name_fr", "product_name_de", "product_name_es", "product_name_it",
            "product_name_pt", "product_name_nl", "product_name_pl", "product_name_ru",
            "product_name_ja", "product_name_ko", "product_name_zh", "product_name_ar",
        ]
        for key in directKeys {
            if let n = nonEmpty(product[key] as? String) { return n }
        }
        if let brands = nonEmpty(product["brands"] as? String) { return brands }

        for key in product.keys.sorted() {
            guard let s = product[key] as? String, let n = nonEmpty(s) else { continue }
            if key.hasPrefix("generic_name") { return n }
        }
        for key in product.keys.sorted() {
            guard let s = product[key] as? String, let n = nonEmpty(s) else { continue }
            if key.hasPrefix("abbreviated_product_name") { return n }
        }
        for key in product.keys.sorted() {
            guard let s = product[key] as? String, let n = nonEmpty(s) else { continue }
            if key.hasPrefix("product_name") { return n }
        }

        if let fromTags = nameFromBrandsTags(product["brands_tags"]) { return fromTags }

        return nil
    }

    static func displayName(from product: [String: Any], barcode: String) -> String {
        resolvedName(from: product) ?? placeholderName(forBarcode: barcode)
    }

    static func placeholderName(forBarcode barcode: String) -> String {
        String(format: String(localized: "Scanned item (%@)"), barcode)
    }

    private static func nameFromBrandsTags(_ value: Any?) -> String? {
        guard let tags = value as? [String] else { return nil }
        let parts = tags.compactMap { tag -> String? in
            let bits = tag.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard bits.count >= 2 else { return nil }
            return nonEmpty(String(bits[1]).replacingOccurrences(of: "-", with: " "))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - Catalog match after barcode scan

enum BarcodeCatalogMatch {
    enum Resolution: Sendable {
        case single(GroceryCatalogItem)
        case chooseAmong([GroceryCatalogItem])
        case useOpenFoodFacts(name: String, category: String)
    }

    static func resolve(
        catalogSearchQuery: String,
        openFoodFactsName: String,
        openFoodFactsCategory: String,
        catalogResults: [GroceryCatalogItem]
    ) -> Resolution {
        let trimmed = catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return .useOpenFoodFacts(name: openFoodFactsName, category: openFoodFactsCategory)
        }

        let results = catalogResults
        if results.isEmpty {
            return .useOpenFoodFacts(name: openFoodFactsName, category: openFoodFactsCategory)
        }

        if results.count == 1, let one = results.first {
            return .single(one)
        }

        if results.count <= 3 {
            return .chooseAmong(results)
        }

        let off = openFoodFactsName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let exactQuery = results.first(where: { $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            return .single(exactQuery)
        }
        if !off.isEmpty, let exactOff = results.first(where: { $0.name.compare(off, options: .caseInsensitive) == .orderedSame }) {
            return .single(exactOff)
        }

        let narrowed = results.prefix(8).filter { item in
            item.name.localizedCaseInsensitiveContains(trimmed)
                || trimmed.localizedCaseInsensitiveContains(item.name)
                || (!off.isEmpty && item.name.localizedCaseInsensitiveContains(off))
        }

        if narrowed.count == 1, let one = narrowed.first {
            return .single(one)
        }
        if narrowed.count >= 2, narrowed.count <= 3 {
            return .chooseAmong(Array(narrowed))
        }

        return .useOpenFoodFacts(name: openFoodFactsName, category: openFoodFactsCategory)
    }
}
