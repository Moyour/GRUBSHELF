import Foundation

enum AnalyticsCard: String, CaseIterable, Identifiable {
    case smartTips
    case wasteTracker
    case monthlySpend
    case categoryBreakdown
    case mostPurchased
    case leastPurchased
    case mostWasted
    case leastWasted
    case mostSpentByItem
    case mostSpentByCategory
    case shoppingEfficiency
    case lowStockCount
    case expiringSoon
    case pantryValue
    case averageTripCost
    case achievements

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartTips: return "Smart Tips"
        case .wasteTracker: return "Waste Tracker"
        case .monthlySpend: return "Monthly Spend"
        case .categoryBreakdown: return "Items by Category"
        case .mostPurchased: return "Most Purchased"
        case .leastPurchased: return "Least Purchased"
        case .mostWasted: return "Most Wasted"
        case .leastWasted: return "Least Wasted"
        case .mostSpentByItem: return "Most Spent by Item"
        case .mostSpentByCategory: return "Most Spent by Category"
        case .shoppingEfficiency: return "Shopping Efficiency"
        case .lowStockCount: return "Low Stock"
        case .expiringSoon: return "Expiring Soon"
        case .pantryValue: return "Pantry Value"
        case .averageTripCost: return "Average Trip Cost"
        case .achievements: return "Achievements"
        }
    }

    var icon: String {
        switch self {
        case .smartTips: return "lightbulb.fill"
        case .wasteTracker: return "trash.circle.fill"
        case .monthlySpend: return "chart.bar.fill"
        case .categoryBreakdown: return "tag.fill"
        case .mostPurchased: return "repeat"
        case .leastPurchased: return "arrow.down.circle"
        case .mostWasted: return "trash.fill"
        case .leastWasted: return "hand.thumbsup.fill"
        case .mostSpentByItem: return "sterlingsign.circle.fill"
        case .mostSpentByCategory: return "chart.pie.fill"
        case .shoppingEfficiency: return "chart.line.uptrend.xyaxis"
        case .lowStockCount: return "cart.badge.plus"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .pantryValue: return "dollarsign.circle.fill"
        case .averageTripCost: return "cart.fill"
        case .achievements: return "trophy.fill"
        }
    }

    var description: String {
        switch self {
        case .smartTips: return "Personalized tips based on your pantry"
        case .wasteTracker: return "Track waste vs last month"
        case .monthlySpend: return "Spending trends over time"
        case .categoryBreakdown: return "Items by category"
        case .mostPurchased: return "Items you buy most often"
        case .leastPurchased: return "Items you buy least often"
        case .mostWasted: return "Items wasted most frequently"
        case .leastWasted: return "Items rarely wasted"
        case .mostSpentByItem: return "Highest spend per item"
        case .mostSpentByCategory: return "Spending by category"
        case .shoppingEfficiency: return "Shopping list completion"
        case .lowStockCount: return "Items running low"
        case .expiringSoon: return "Items expiring soon"
        case .pantryValue: return "Total pantry value"
        case .averageTripCost: return "Average cost per trip"
        case .achievements: return "Unlock badges"
        }
    }

    /// Order for display (lower = earlier)
    var displayOrder: Int {
        switch self {
        case .smartTips: return 0
        case .wasteTracker: return 1
        case .monthlySpend: return 2
        case .categoryBreakdown: return 3
        case .mostPurchased: return 4
        case .leastPurchased: return 5
        case .mostWasted: return 6
        case .leastWasted: return 7
        case .mostSpentByItem: return 8
        case .mostSpentByCategory: return 9
        case .shoppingEfficiency: return 10
        case .lowStockCount: return 11
        case .expiringSoon: return 12
        case .pantryValue: return 13
        case .averageTripCost: return 14
        case .achievements: return 15
        }
    }

    static var defaultEnabled: Set<AnalyticsCard> {
        [.smartTips, .wasteTracker, .monthlySpend, .categoryBreakdown, .mostPurchased, .shoppingEfficiency, .achievements]
    }
}

// MARK: - Analytics Preferences

enum AnalyticsPreferences {
    private static let key = "analytics_enabled_cards"

    static var enabledCards: Set<AnalyticsCard> {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let raw = try? JSONDecoder().decode([String].self, from: data) else {
                return AnalyticsCard.defaultEnabled
            }
            return Set(raw.compactMap { AnalyticsCard(rawValue: $0) })
        }
        set {
            let raw = Array(newValue.map(\.rawValue))
            if let data = try? JSONEncoder().encode(raw) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    static func isEnabled(_ card: AnalyticsCard) -> Bool {
        enabledCards.contains(card)
    }

    static func setEnabled(_ card: AnalyticsCard, _ enabled: Bool) {
        var cards = enabledCards
        if enabled {
            cards.insert(card)
        } else {
            cards.remove(card)
        }
        enabledCards = cards
    }

    static var enabledCardsSorted: [AnalyticsCard] {
        AnalyticsCard.allCases
            .filter { isEnabled($0) }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
}
