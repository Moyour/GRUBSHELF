import Foundation
import Observation

enum AuditResolution: Hashable, CaseIterable {
    case usedAll
    case stillHaveSome
    case wentBad

    var label: String {
        switch self {
        case .usedAll: return "Used up"
        case .stillHaveSome: return "Have some"
        case .wentBad: return "Went bad"
        }
    }

    var systemImage: String {
        switch self {
        case .usedAll: return "checkmark.circle"
        case .stillHaveSome: return "plus.circle"
        case .wentBad: return "trash.circle"
        }
    }
}

struct AuditEntry: Identifiable {
    let id: UUID
    let shoppingItem: ShoppingItem
    var matchedPantryItem: PantryItem?
    var resolution: AuditResolution
}

@MainActor
@Observable
final class ShoppingAuditViewModel {
    var entries: [AuditEntry] = []
    var orphanedItems: [PantryItem]

    var matchedEntries: [AuditEntry] {
        entries.filter { $0.matchedPantryItem != nil }
    }

    var unmatchedEntries: [AuditEntry] {
        entries.filter { $0.matchedPantryItem == nil }
    }

    var hasMatches: Bool {
        entries.contains { $0.matchedPantryItem != nil }
    }

    init(transferableItems: [ShoppingItem], pantryItems: [PantryItem]) {
        var usedPantryIds = Set<UUID>()
        var builtEntries: [AuditEntry] = []

        for item in transferableItems {
            let match = pantryItems.first { pantry in
                !pantry.archived
                    && !usedPantryIds.contains(pantry.itemId)
                    && pantry.name.caseInsensitiveCompare(item.name) == .orderedSame
            }

            if let match {
                usedPantryIds.insert(match.itemId)
            }

            let defaultResolution: AuditResolution = {
                if let match {
                    return Self.smartDefault(for: match.category)
                } else {
                    return .usedAll
                }
            }()

            builtEntries.append(AuditEntry(
                id: item.itemId,
                shoppingItem: item,
                matchedPantryItem: match,
                resolution: defaultResolution
            ))
        }

        self.entries = builtEntries
        self.orphanedItems = pantryItems.filter { pantry in
            !pantry.archived
                && !usedPantryIds.contains(pantry.itemId)
                && pantry.isStale
        }
    }

    private static let perishableCategories: Set<String> = [
        "fruits", "vegetables", "dairy", "meat", "seafood", "bakery"
    ]

    static func smartDefault(for category: String) -> AuditResolution {
        perishableCategories.contains(category.lowercased()) ? .usedAll : .stillHaveSome
    }
}

