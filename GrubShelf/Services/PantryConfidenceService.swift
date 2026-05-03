import Foundation

enum PantryConfidenceService {
    enum Tier {
        case confident
        case uncertain
        case probablyGone

        init(confidence: Double) {
            switch confidence {
            case 0.7...: self = .confident
            case 0.3..<0.7: self = .uncertain
            default: self = .probablyGone
            }
        }
    }

    static func confidence(for item: PantryItem) -> Double {
        guard let cycleDays = item.expectedUsageCycleDays, cycleDays > 0 else {
            return 1.0
        }

        let lastUpdate = item.lastQuantityUpdateDate ?? item.updatedAt
        let daysSince = Calendar.current.dateComponents([.day], from: lastUpdate, to: .now).day ?? 0

        guard daysSince > cycleDays else { return 1.0 }

        let overdueDays = daysSince - cycleDays
        let decayRate = decayPerDay(for: item.category)
        let confidence = max(0.0, 1.0 - Double(overdueDays) * decayRate)
        return confidence
    }

    private static let perishableCategories: Set<String> = [
        "fruits", "vegetables", "dairy", "meat", "seafood", "bakery"
    ]

    private static func decayPerDay(for category: String) -> Double {
        perishableCategories.contains(category.lowercased())
            ? 0.1          // perishables lose 10% confidence per overdue day
            : 0.05 / 7.0  // staples lose 5% per overdue week (~0.7% per day)
    }
}
