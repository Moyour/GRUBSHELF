import Foundation
import Observation
import os

@MainActor
@Observable
final class DashboardViewModel {
    private static let dashboard = Logger(subsystem: "com.grubshelf", category: "Dashboard")
    var expiringItems: [PantryItem] = []
    var staleItems: [PantryItem] = []
    var totalPantryItems = 0
    var categoriesCount = 0
    var lowStockCount = 0
    var staleCount = 0
    var shoppingTotal = 0
    var shoppingCompleted = 0
    var expiredCount = 0
    var activeItemCount = 0
    var isLoading = false
    var hasLoaded = false
    var pendingApprovalsCount = 0

    // Activity metrics
    var mostPurchasedItem: String?
    var mostPurchasedCount: Int = 0
    var mostWastedItem: String?
    var mostWastedCount: Int = 0
    var wasteItemCount: Int = 0
    var wasteTotalMinor: Int = 0

    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    let pantryRepository: PantryRepository
    let shoppingRepository: ShoppingRepository
    private let transactionRepository: TransactionRepository
    private let wasteEventRepository: WasteEventRepository
    let householdId: UUID
    let userId: UUID
    let userRole: UserRole
    private let approvalService: ApprovalService

    var isAdmin: Bool { userRole == .admin }

    /// Single neutral headline for the home overview (no time-of-day greeting).
    var overviewHeadline: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var completionPercentage: Double {
        guard shoppingTotal > 0 else { return 0 }
        return Double(shoppingCompleted) / Double(shoppingTotal) * 100
    }

    // MARK: - Pantry Health Score (0–100)

    var healthScore: Int {
        guard totalPantryItems > 0 else { return 100 }

        let expiryPenalty = Double(expiringItems.count) / Double(totalPantryItems)
        let lowStockPenalty = Double(lowStockCount) / Double(totalPantryItems)
        let shoppingBonus: Double = completionPercentage / 100.0 * 0.1

        let raw = 1.0 - (expiryPenalty * 0.5 + lowStockPenalty * 0.4) + shoppingBonus
        return max(0, min(100, Int(raw * 100)))
    }

    var healthLabel: String {
        switch healthScore {
        case 80...100: return "Strong"
        case 60..<80: return "Stable"
        case 40..<60: return "Needs attention"
        default: return "Action recommended"
        }
    }

    // MARK: - Action Pill Counts

    var expiringCount: Int { expiringItems.count }
    var pendingShoppingCount: Int { shoppingTotal - shoppingCompleted }

    // MARK: - Streak

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: "streak_count")
    }

    func recordStreakVisit() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let lastVisit = defaults.object(forKey: "streak_last_date") as? Date ?? .distantPast
        let lastDay = calendar.startOfDay(for: lastVisit)

        if calendar.isDate(today, inSameDayAs: lastDay) {
            return
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        if calendar.isDate(lastDay, inSameDayAs: yesterday) {
            defaults.set(currentStreak + 1, forKey: "streak_count")
        } else {
            defaults.set(1, forKey: "streak_count")
        }
        defaults.set(today, forKey: "streak_last_date")
    }

    // MARK: - Init & Load

    init(
        pantryRepository: PantryRepository,
        shoppingRepository: ShoppingRepository,
        transactionRepository: TransactionRepository = SupabaseTransactionRepository(),
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member,
        approvalService: ApprovalService = ApprovalService()
    ) {
        self.pantryRepository = pantryRepository
        self.shoppingRepository = shoppingRepository
        self.transactionRepository = transactionRepository
        self.wasteEventRepository = wasteEventRepository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
        self.approvalService = approvalService
    }

    private static func pendingCount(pantry: [PantryItem], shopping: [ShoppingItem]) -> Int {
        pantry.filter { $0.approvalStatus == .pending }.count
            + shopping.filter { $0.approvalStatus == .pending }.count
    }

    func syncPendingApprovalsCount(pantryItems: [PantryItem], shoppingItems: [ShoppingItem]) {
        guard isAdmin else {
            pendingApprovalsCount = 0
            return
        }
        pendingApprovalsCount = Self.pendingCount(pantry: pantryItems, shopping: shoppingItems)
    }

    func loadData(forceRefresh: Bool = false, authService: AuthenticationService? = nil) async {
        do {
            try await loadDataInternal(forceRefresh: forceRefresh)
        } catch {
            guard isAuthenticationError(error), let authService else { return }
            Self.dashboard.info("Detected auth error, attempting session refresh...")
            do {
                try await authService.refreshSession()
                try await loadDataInternal(forceRefresh: true)
                ToastManager.shared.show("Session refreshed", style: .success)
            } catch {
                Self.dashboard.error("Session refresh failed: \(error.localizedDescription)")
                ToastManager.shared.show("Please sign out and back in", style: .error)
            }
        }
    }

    private func isAuthenticationError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("jwt")
            || description.contains("token")
            || description.contains("401")
            || description.contains("authentication")
            || description.contains("unauthorized")
    }

    private func loadDataInternal(forceRefresh: Bool) async throws {
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        isLoading = true
        do {
            async let pantryFetch = pantryRepository.fetchAll(householdId: householdId)
            async let shoppingFetch = shoppingRepository.fetchAll(householdId: householdId)
            let (allPantryItems, allShoppingItems) = try await (pantryFetch, shoppingFetch)
            let pantryItems = allPantryItems.filter { $0.approvalStatus == .approved }
            let shoppingItems = allShoppingItems.filter { $0.approvalStatus == .approved }

            totalPantryItems = pantryItems.count
            categoriesCount = Set(pantryItems.map(\.category)).count
            lowStockCount = pantryItems.filter { $0.state == .lowStock }.count
            expiredCount = pantryItems.filter { $0.state == .expired }.count
            activeItemCount = pantryItems.filter { $0.state == .active || $0.state == .lowStock }.count
            staleItems = pantryItems.filter { $0.state == .stale }
            staleCount = staleItems.count
            expiringItems = pantryItems.filter {
                $0.state == .expiringSoon || $0.state == .expired
            }
            .sorted { lhs, rhs in
                (lhs.expiryDate ?? .distantFuture) < (rhs.expiryDate ?? .distantFuture)
            }

            shoppingTotal = shoppingItems.count
            shoppingCompleted = shoppingItems.filter(\.completed).count

            if isAdmin {
                pendingApprovalsCount = Self.pendingCount(
                    pantry: allPantryItems,
                    shopping: allShoppingItems
                )
                if let counts = try? await approvalService.fetchPendingCounts(householdId: householdId) {
                    pendingApprovalsCount = counts.total
                }
            } else {
                pendingApprovalsCount = 0
            }

            await loadActivityMetrics(pantryItems: pantryItems)
            autoArchiveExpiredItems(pantryItems)
        } catch {
            Self.dashboard.error("Dashboard load failed: \(error.localizedDescription)")
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "refresh your overview"),
                style: .error
            )
            throw error
        }
        isLoading = false
        hasLoaded = true
        lastLoadedAt = .now
        recordStreakVisit()
    }

    // MARK: - Activity Metrics

    private func loadActivityMetrics(pantryItems: [PantryItem]) async {
        let calendar = Calendar.current
        let now = Date.now
        let comps = calendar.dateComponents([.year, .month], from: now)
        let period = String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)

        // Most purchased (from recent transactions)
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let transactions = (try? await transactionRepository.fetchByDateRange(
            householdId: householdId, start: threeMonthsAgo, end: now
        )) ?? []

        if !transactions.isEmpty {
            let itemNameLookup = Dictionary(uniqueKeysWithValues: pantryItems.map { ($0.itemId, $0.name) })
            var freq: [String: Int] = [:]
            for t in transactions {
                let name = t.itemId.flatMap { itemNameLookup[$0] } ?? t.storeName ?? "Unknown"
                freq[name, default: 0] += 1
            }
            if let top = freq.max(by: { $0.value < $1.value }) {
                mostPurchasedItem = top.key
                mostPurchasedCount = top.value
            }
        }

        // Waste this period
        let wasteEvents = (try? await wasteEventRepository.fetchByPeriod(
            householdId: householdId, period: period
        )) ?? []

        wasteItemCount = wasteEvents.count
        wasteTotalMinor = wasteEvents.reduce(0) { $0 + ($1.estimatedCostMinor ?? 0) }

        // Most wasted item
        if !wasteEvents.isEmpty {
            var wasteFreq: [String: Int] = [:]
            for e in wasteEvents {
                wasteFreq[e.itemName, default: 0] += 1
            }
            if let topWaste = wasteFreq.max(by: { $0.value < $1.value }) {
                mostWastedItem = topWaste.key
                mostWastedCount = topWaste.value
            }
        }
    }

    // MARK: - Auto-Archive Expired Items

    private func autoArchiveExpiredItems(_ items: [PantryItem]) {
        let enabled = UserDefaults.standard.object(forKey: "autoArchiveExpired") as? Bool ?? false
        guard enabled else { return }

        let graceDays = UserDefaults.standard.integer(forKey: "autoArchiveGraceDays")
        let effectiveGrace = graceDays > 0 ? graceDays : 3

        let now = Date.now
        let calendar = Calendar.current

        // Items past grace period — ready to archive
        let toArchive = items.filter { item in
            guard let expiry = item.expiryDate, !item.archived else { return false }
            let daysPastExpiry = calendar.dateComponents([.day], from: expiry, to: now).day ?? 0
            return daysPastExpiry >= effectiveGrace
        }

        // Items approaching grace period (1 day before) — warn the user
        let approachingArchive = items.filter { item in
            guard let expiry = item.expiryDate, !item.archived else { return false }
            let daysPastExpiry = calendar.dateComponents([.day], from: expiry, to: now).day ?? 0
            return daysPastExpiry == effectiveGrace - 1
        }

        // Send warning notification for items about to be archived
        if !approachingArchive.isEmpty {
            NotificationService.shared.scheduleAutoArchiveWarning(items: approachingArchive)
        }

        guard !toArchive.isEmpty else { return }

        Task {
            var archived = 0
            var failed = 0
            for item in toArchive {
                var updated = item
                updated.archived = true
                updated.updatedAt = .now
                do {
                    _ = try await pantryRepository.update(updated)
                    archived += 1
                } catch {
                    failed += 1
                    Self.dashboard.warning("Auto-archive failed for \(updated.name): \(String(describing: error))")
                }
            }
            if archived > 0 && failed == 0 {
                ToastManager.shared.show("\(archived) expired item\(archived == 1 ? "" : "s") archived", style: .success)
            } else if archived > 0 && failed > 0 {
                ToastManager.shared.show("\(archived) archived, \(failed) failed", style: .error)
            } else if failed > 0 {
                ToastManager.shared.show("Failed to archive expired items", style: .error)
            }
        }
    }
}
