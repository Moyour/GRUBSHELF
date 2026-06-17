import Foundation

/// Search ranking and identity helpers for the full `grocery_catalog` table.
/// Every catalog row has a unique `catalog_item_id`; shopping lines stay separate per product.
enum GroceryCatalogSearchRanker {
    /// Filters and ranks catalog hits for autocomplete. Hides misleading substring
    /// matches (e.g. "Watermelon" for "water", "Pineapple" for "apple") while
    /// keeping exact matches and true multi-word hits ("Sparkling Water", "Black Tea").
    static func suggestions(from items: [GroceryCatalogItem], query: String, limit: Int = 5) -> [GroceryCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let ranked = ranked(items, query: trimmed)
        let filtered = filterMisleadingSubstringMatches(ranked, query: trimmed)
        let capped = Array(filtered.prefix(limit))
        return uniqueByCatalogName(uniqueByCatalogId(capped))
    }

    /// One row per `catalog_item_id` (ForEach identity + distinct products).
    static func uniqueByCatalogId(_ items: [GroceryCatalogItem]) -> [GroceryCatalogItem] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.catalogItemId).inserted }
    }

    /// One suggestion per display name (legacy duplicate catalog rows collapse to a single tap target).
    static func uniqueByCatalogName(_ items: [GroceryCatalogItem]) -> [GroceryCatalogItem] {
        var seen = Set<String>()
        return items.filter {
            let key = $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return seen.insert(key).inserted
        }
    }

    static func ranked(_ items: [GroceryCatalogItem], query: String) -> [GroceryCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        return items.sorted { lhs, rhs in
            let left = score(for: lhs.name, query: trimmed)
            let right = score(for: rhs.name, query: trimmed)
            if left.tier != right.tier { return left.tier < right.tier }
            if left.secondary != right.secondary { return left.secondary < right.secondary }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func exactMatch(in items: [GroceryCatalogItem], query: String) -> GroceryCatalogItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return items.first { shoppingNamesMatch($0.name, trimmed) }
    }

    static func shoppingNamesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// True when a shopping line refers to the same catalog product (UUID required on the line).
    static func matchesCatalog(_ item: ShoppingItem, catalog: GroceryCatalogItem) -> Bool {
        guard let id = item.catalogItemId else { return false }
        return id == catalog.catalogItemId
    }

    /// Same product again → bump quantity. Different products stay separate.
    /// Uses `catalog_item_id` when present; otherwise exact name match (legacy free-text rows).
    static func shouldCombineShoppingQuantity(
        existing: ShoppingItem,
        newCatalogId: UUID?
    ) -> Bool {
        guard existing.isApproved, !existing.completed else { return false }
        guard let newCatalogId else { return false }
        if let existingCatalogId = existing.catalogItemId {
            return existingCatalogId == newCatalogId
        }
        return false
    }

    static func shouldCombineShoppingQuantity(
        existing: ShoppingItem,
        newName: String,
        newCatalogId: UUID?
    ) -> Bool {
        guard existing.isApproved, !existing.completed else { return false }
        if let newCatalogId, let existingCatalogId = existing.catalogItemId {
            return existingCatalogId == newCatalogId
        }
        if newCatalogId == nil, existing.catalogItemId == nil {
            return shoppingNamesMatch(existing.name, newName)
        }
        return false
    }

    static func shouldCombineShoppingQuantity(
        existing: ShoppingItem,
        catalog: GroceryCatalogItem
    ) -> Bool {
        guard existing.isApproved, !existing.completed else { return false }
        if let existingCatalogId = existing.catalogItemId {
            return existingCatalogId == catalog.catalogItemId
        }
        return shoppingNamesMatch(existing.name, catalog.name)
    }

    // MARK: - Private

    private struct Score: Comparable {
        let tier: Int
        let secondary: Int

        static func < (lhs: Score, rhs: Score) -> Bool {
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            return lhs.secondary < rhs.secondary
        }
    }

    /// A hit where `query` appears inside a longer name but is not the full name
    /// and not on a word boundary — e.g. "apple" inside "Pineapple", "water" inside
    /// "Watermelon", "berry" inside "Blackberry".
    private static func isEmbeddedSubstringTrap(name: String, query: String) -> Bool {
        let lowerName = name.lowercased()
        let lowerQuery = query.lowercased()
        guard lowerName != lowerQuery else { return false }
        guard lowerName.contains(lowerQuery) else { return false }
        if matchesWordBoundary(in: lowerName, query: lowerQuery) { return false }

        if lowerName.hasPrefix(lowerQuery) {
            let afterIndex = lowerName.index(lowerName.startIndex, offsetBy: lowerQuery.count)
            guard afterIndex < lowerName.endIndex else { return false }
            // "Water Chestnut" → space after "water" → valid multi-word prefix, not a trap.
            return lowerName[afterIndex].isLetter
        }
        // Infix / suffix: "apple" in "pineapple", "berry" in "strawberry".
        return true
    }

    private static func filterMisleadingSubstringMatches(
        _ items: [GroceryCatalogItem],
        query: String
    ) -> [GroceryCatalogItem] {
        let lowerQuery = query.lowercased()
        let hasStrongMatch = items.contains { score(for: $0.name, query: query).tier <= 2 }

        return items.filter { item in
            guard isEmbeddedSubstringTrap(name: item.name, query: query) else { return true }

            let lowerName = item.name.lowercased()
            // User typed far enough into the longer name to disambiguate intentionally.
            if lowerName.hasPrefix(lowerQuery), lowerQuery.count >= 6 {
                return true
            }
            if !hasStrongMatch {
                return true
            }
            return false
        }
    }

    private static func score(for name: String, query: String) -> Score {
        let lowerName = name.lowercased()
        let lowerQuery = query.lowercased()

        if lowerName == lowerQuery {
            return Score(tier: 0, secondary: name.count)
        }
        if lowerName.hasPrefix(lowerQuery), !isEmbeddedSubstringTrap(name: name, query: query) {
            return Score(tier: 1, secondary: name.count)
        }
        if matchesWordBoundary(in: lowerName, query: lowerQuery) {
            return Score(tier: 2, secondary: name.count)
        }
        if lowerName.contains(lowerQuery) {
            return Score(tier: 3, secondary: name.count)
        }
        return Score(tier: 4, secondary: name.count)
    }

    private static func matchesWordBoundary(in name: String, query: String) -> Bool {
        var start = name.startIndex
        while start < name.endIndex {
            guard let range = name.range(of: query, range: start..<name.endIndex) else { return false }
            let beforeOk = range.lowerBound == name.startIndex || !name[name.index(before: range.lowerBound)].isLetter
            let afterOk = range.upperBound == name.endIndex || !name[range.upperBound].isLetter
            if beforeOk && afterOk { return true }
            start = range.upperBound
        }
        return false
    }
}
