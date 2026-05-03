import Foundation
import Observation

struct MonthlySpend: Identifiable {
    let id = UUID()
    let month: String
    let amount: Int
}

struct ItemFrequency: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct CategorySpend: Identifiable {
    let id = UUID()
    let category: String
    let amount: Int
}

struct ItemSpend: Identifiable {
    let id = UUID()
    let name: String
    let amountMinor: Int
}

struct CategorySpendAmount: Identifiable {
    let id = UUID()
    let category: String
    let amountMinor: Int
}

struct SmartTip: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let color: TipColor

    enum TipColor {
        case warning, success, info
    }
}

@MainActor
@Observable
final class InsightsViewModel {
    var monthlySpendData: [MonthlySpend] = []
    var wasteEstimate: Int = 0
    var lastMonthWaste: Int = 0
    var mostPurchasedItems: [ItemFrequency] = []
    var leastPurchasedItems: [ItemFrequency] = []
    var mostWastedItems: [ItemSpend] = []
    var leastWastedItems: [ItemSpend] = []
    var mostSpentByItem: [ItemSpend] = []
    var mostSpentByCategory: [CategorySpendAmount] = []
    var totalPantryValueMinor: Int = 0
    var averageTripCostMinor: Int = 0
    var categoryBreakdown: [CategorySpend] = []
    var smartTips: [SmartTip] = []
    var isLoading = false
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    var totalPantryItems = 0
    var categoriesCount = 0
    var lowStockCount = 0
    var expiredCount = 0
    var activeItemCount = 0
    var shoppingTotal = 0
    var shoppingCompleted = 0
    var expiringItems: [PantryItem] = []

    private let financialService: FinancialService
    private let transactionRepository: TransactionRepository
    private let pantryRepository: PantryRepository
    private let shoppingRepository: ShoppingRepository
    private let shoppingTripRepository: ShoppingTripRepository
    private let wasteEventRepository: WasteEventRepository
    private let householdId: UUID

    // MARK: - Achievements

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: "streak_count")
    }

    var unlockedAchievements: [Achievement] {
        Achievement.allCases.filter { isUnlocked($0) }
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        switch achievement {
        case .firstItem: return totalPantryItems >= 1
        case .stockedUp: return totalPantryItems >= 10
        case .zeroWaste: return totalPantryItems > 0 && expiredCount == 0
        case .shoppingPro: return shoppingTotal > 0 && shoppingCompleted == shoppingTotal
        case .streak7: return currentStreak >= 7
        case .organizer: return categoriesCount >= 5
        }
    }

    // MARK: - Shopping Efficiency

    var shoppingCompletionRate: Double {
        guard shoppingTotal > 0 else { return 0 }
        return Double(shoppingCompleted) / Double(shoppingTotal) * 100
    }

    // MARK: - Waste Comparison

    var wasteChangeDirection: WasteDirection {
        if lastMonthWaste == 0 && wasteEstimate == 0 { return .flat }
        if wasteEstimate < lastMonthWaste { return .down }
        if wasteEstimate > lastMonthWaste { return .up }
        return .flat
    }

    enum WasteDirection {
        case up, down, flat
    }

    // MARK: - Init

    init(
        financialService: FinancialService = FinancialService(),
        transactionRepository: TransactionRepository = SupabaseTransactionRepository(),
        pantryRepository: PantryRepository = SupabasePantryRepository(),
        shoppingRepository: ShoppingRepository = SupabaseShoppingRepository(),
        shoppingTripRepository: ShoppingTripRepository = SupabaseShoppingTripRepository(),
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        householdId: UUID
    ) {
        self.financialService = financialService
        self.transactionRepository = transactionRepository
        self.pantryRepository = pantryRepository
        self.shoppingRepository = shoppingRepository
        self.shoppingTripRepository = shoppingTripRepository
        self.wasteEventRepository = wasteEventRepository
        self.householdId = householdId
    }

    // MARK: - Load

    func loadData(forceRefresh: Bool = false) async {
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        isLoading = true

        let calendar = Calendar.current
        let now = Date.now
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now

        // Parallel fetches: pantry, shopping, monthly spend batch, transactions, waste events, trips
        async let pantryFetch = pantryRepository.fetchAll(householdId: householdId)
        async let shoppingFetch = shoppingRepository.fetchAll(householdId: householdId)
        async let spendFetch = financialService.monthlySpendBatch(householdId: householdId)
        async let transactionFetch = transactionRepository.fetchByDateRange(
            householdId: householdId, start: threeMonthsAgo, end: now
        )
        async let wasteEventsFetch = wasteEventRepository.fetchByDateRange(
            householdId: householdId, start: sixMonthsAgo, end: now
        )
        async let tripsFetch = shoppingTripRepository.fetchByDateRange(
            householdId: householdId, start: sixMonthsAgo, end: now
        )

        // Pantry data
        let pantryItems = (try? await pantryFetch) ?? []
        totalPantryItems = pantryItems.count
        categoriesCount = Set(pantryItems.map(\.category)).count
        lowStockCount = pantryItems.filter { $0.state == .lowStock }.count
        expiredCount = pantryItems.filter { $0.state == .expired }.count
        activeItemCount = pantryItems.filter { $0.state == .active || $0.state == .lowStock }.count
        expiringItems = pantryItems.filter { $0.state == .expiringSoon || $0.state == .expired }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }

        // Category breakdown from pantry items
        var catCounts: [String: Int] = [:]
        for item in pantryItems {
            catCounts[item.category, default: 0] += 1
        }
        categoryBreakdown = catCounts.map { CategorySpend(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        // Shopping data
        let shoppingItems = (try? await shoppingFetch) ?? []
        shoppingTotal = shoppingItems.count
        shoppingCompleted = shoppingItems.filter(\.completed).count

        // Monthly spend (single batch query)
        monthlySpendData = (try? await spendFetch) ?? []

        // Waste: use already-fetched pantry items for current estimate
        wasteEstimate = pantryItems
            .filter { $0.state == .expired }
            .reduce(0) { $0 + Int($1.quantity * Double($1.costPerUnitMinor ?? 0)) }

        // Last month's waste from waste event history
        let lastMonthComps = calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -1, to: now) ?? now)
        let lastMonthPeriod = String(format: "%d-%02d", lastMonthComps.year ?? 1970, lastMonthComps.month ?? 1)
        let lastMonthEvents = (try? await wasteEventRepository.fetchByPeriod(householdId: householdId, period: lastMonthPeriod)) ?? []
        lastMonthWaste = lastMonthEvents.reduce(0) { $0 + ($1.estimatedCostMinor ?? 0) }

        // Most purchased (from transactions, matched to pantry item names)
        let transactions = (try? await transactionFetch) ?? []
        let itemNameLookup = Dictionary(uniqueKeysWithValues: pantryItems.map { ($0.itemId, $0.name) })
        var freq: [String: Int] = [:]
        for t in transactions {
            let name = t.itemId.flatMap { itemNameLookup[$0] } ?? t.storeName ?? "Unknown"
            freq[name, default: 0] += 1
        }
        mostPurchasedItems = freq.map { ItemFrequency(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }

        leastPurchasedItems = freq.map { ItemFrequency(name: $0.key, count: $0.value) }
            .sorted { $0.count < $1.count }
            .prefix(5)
            .map { $0 }

        // Most/least spent by item
        var spendByItem: [String: Int] = [:]
        for t in transactions {
            let name = t.itemId.flatMap { itemNameLookup[$0] } ?? t.storeName ?? "Unknown"
            spendByItem[name, default: 0] += t.totalCostMinor
        }
        mostSpentByItem = spendByItem.map { ItemSpend(name: $0.key, amountMinor: $0.value) }
            .sorted { $0.amountMinor > $1.amountMinor }
            .prefix(5)
            .map { $0 }

        // Most spent by category
        var spendByCategory: [String: Int] = [:]
        for t in transactions {
            guard let itemId = t.itemId else { continue }
            let category = pantryItems.first { $0.itemId == itemId }?.category ?? "Other"
            spendByCategory[category, default: 0] += t.totalCostMinor
        }
        mostSpentByCategory = spendByCategory.map { CategorySpendAmount(category: $0.key, amountMinor: $0.value) }
            .sorted { $0.amountMinor > $1.amountMinor }
            .prefix(5)
            .map { $0 }

        // Total pantry value
        totalPantryValueMinor = pantryItems
            .filter { !$0.archived && $0.quantity > 0 }
            .reduce(0) { $0 + Int($1.quantity * Double($1.costPerUnitMinor ?? 0)) }

        // Waste events: most/least wasted
        let wasteEvents = (try? await wasteEventsFetch) ?? []
        var wasteByItem: [String: Int] = [:]
        for e in wasteEvents {
            wasteByItem[e.itemName, default: 0] += e.estimatedCostMinor ?? 0
        }
        let wasteSpends = wasteByItem.map { ItemSpend(name: $0.key, amountMinor: $0.value) }
        mostWastedItems = wasteSpends.sorted { $0.amountMinor > $1.amountMinor }.prefix(5).map { $0 }
        leastWastedItems = wasteSpends.sorted { $0.amountMinor < $1.amountMinor }.prefix(5).map { $0 }

        // Average trip cost
        let trips = (try? await tripsFetch) ?? []
        let loggedTrips = trips.filter { $0.costLogged && ($0.totalCostMinor ?? 0) > 0 }
        if !loggedTrips.isEmpty {
            let total = loggedTrips.compactMap(\.totalCostMinor).reduce(0, +)
            averageTripCostMinor = total / loggedTrips.count
        } else {
            averageTripCostMinor = 0
        }

        // Generate smart tips
        generateSmartTips()

        isLoading = false
        lastLoadedAt = .now
    }

    // MARK: - Smart Tips Generation

    private func generateSmartTips() {
        var tips: [SmartTip] = []

        if let urgentItem = expiringItems.first, let expiry = urgentItem.expiryDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expiry)).day ?? 0
            if days <= 1 {
                tips.append(SmartTip(
                    icon: "exclamationmark.triangle.fill",
                    message: "Your \(urgentItem.name) expires \(days <= 0 ? "today" : "tomorrow") — use it now!",
                    color: .warning
                ))
            }
        }

        if expiredCount == 0 && totalPantryItems > 0 {
            tips.append(SmartTip(
                icon: "hand.thumbsup.fill",
                message: "Zero waste this month — keep it up!",
                color: .success
            ))
        }

        if expiredCount > 0 {
            tips.append(SmartTip(
                icon: "trash.fill",
                message: "\(expiredCount) item\(expiredCount == 1 ? "" : "s") expired. Consider buying smaller quantities.",
                color: .warning
            ))
        }

        if lowStockCount > 0 {
            tips.append(SmartTip(
                icon: "cart.badge.plus",
                message: "\(lowStockCount) item\(lowStockCount == 1 ? " is" : "s are") running low — add to your shopping list.",
                color: .info
            ))
        }

        if shoppingTotal > 0 && shoppingCompleted == shoppingTotal {
            tips.append(SmartTip(
                icon: "checkmark.circle.fill",
                message: "Shopping list complete! Ready to transfer to pantry?",
                color: .success
            ))
        }

        if totalPantryItems == 0 {
            tips.append(SmartTip(
                icon: "sparkles",
                message: "Start by adding items to your pantry to get personalized insights.",
                color: .info
            ))
        }

        smartTips = tips
    }
}

// MARK: - Achievement Model

enum Achievement: String, CaseIterable, Identifiable {
    case firstItem
    case stockedUp
    case zeroWaste
    case shoppingPro
    case streak7
    case organizer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstItem: return "First Item"
        case .stockedUp: return "Stocked Up"
        case .zeroWaste: return "Zero Waste"
        case .shoppingPro: return "Shop Pro"
        case .streak7: return "On Fire"
        case .organizer: return "Organizer"
        }
    }

    var icon: String {
        switch self {
        case .firstItem: return "leaf.fill"
        case .stockedUp: return "tray.full.fill"
        case .zeroWaste: return "shield.checkered"
        case .shoppingPro: return "cart.fill"
        case .streak7: return "flame.fill"
        case .organizer: return "tag.fill"
        }
    }

    var requirement: String {
        switch self {
        case .firstItem: return "Add your first item"
        case .stockedUp: return "Track 10+ items"
        case .zeroWaste: return "No expired items"
        case .shoppingPro: return "Complete a shopping list"
        case .streak7: return "7-day streak"
        case .organizer: return "Use 5+ categories"
        }
    }
}
