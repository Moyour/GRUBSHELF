import Foundation
import Observation

@MainActor
@Observable
final class FinanceViewModel {
    var financeSettings: FinanceSettings?
    var trips: [ShoppingTrip] = []
    var wasteEvents: [WasteEvent] = []
    var historicalSnapshots: [PeriodSnapshot] = []
    var isLoading = false
    var tripToLog: ShoppingTrip?
    var retroactiveCostText = ""

    private let financeSettingsRepository: FinanceSettingsRepository
    private let shoppingTripRepository: ShoppingTripRepository
    private let wasteEventRepository: WasteEventRepository
    private let periodSnapshotRepository: PeriodSnapshotRepository
    private let householdId: UUID
    let userId: UUID

    init(
        financeSettingsRepository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository(),
        shoppingTripRepository: ShoppingTripRepository = SupabaseShoppingTripRepository(),
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        periodSnapshotRepository: PeriodSnapshotRepository = SupabasePeriodSnapshotRepository(),
        householdId: UUID,
        userId: UUID
    ) {
        self.financeSettingsRepository = financeSettingsRepository
        self.shoppingTripRepository = shoppingTripRepository
        self.wasteEventRepository = wasteEventRepository
        self.periodSnapshotRepository = periodSnapshotRepository
        self.householdId = householdId
        self.userId = userId
    }

    // MARK: - Computed Values

    var hasBudget: Bool { financeSettings != nil }

    var budgetAmountMinor: Int { financeSettings?.budgetAmountMinor ?? 0 }

    var totalSpentMinor: Int {
        trips.compactMap(\.totalCostMinor).reduce(0, +)
    }

    var budgetRemainingMinor: Int {
        budgetAmountMinor - totalSpentMinor
    }

    var spendProgress: Double {
        guard budgetAmountMinor > 0 else { return 0 }
        return min(Double(totalSpentMinor) / Double(budgetAmountMinor), 1.0)
    }

    var budgetColor: BudgetHealthColor {
        guard budgetAmountMinor > 0 else { return .green }
        let remaining = Double(budgetRemainingMinor) / Double(budgetAmountMinor)
        if remaining < 0 { return .red }
        if remaining < 0.1 { return .red }
        if remaining < 0.5 { return .amber }
        return .green
    }

    var wasteTotalMinor: Int {
        wasteEvents.compactMap(\.estimatedCostMinor).reduce(0, +)
    }

    var wasteItemCount: Int { wasteEvents.count }

    var hasWasteCostData: Bool {
        wasteEvents.contains { $0.estimatedCostMinor != nil }
    }

    var effectiveValueMinor: Int {
        totalSpentMinor - wasteTotalMinor
    }

    var unloggedTrips: [ShoppingTrip] {
        trips.filter { !$0.costLogged }
    }

    var currentPeriodLabel: String {
        guard let settings = financeSettings else { return "This Period" }
        switch settings.budgetPeriod {
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        }
    }

    /// Currency code from budget settings, or "GBP" if not configured.
    var currencyCode: String {
        financeSettings?.currency ?? "GBP"
    }

    // MARK: - Data Loading

    func loadData(forceRefresh: Bool = false) async {
        isLoading = true

        do {
            financeSettings = try await financeSettingsRepository.fetch(userId: userId)
        } catch {
            // First-time user with no finance settings — expected, proceed without budget
        }

        guard let settings = financeSettings else {
            isLoading = false
            return
        }

        let period = computeCurrentPeriod(settings: settings)

        // Check if we need to snapshot the previous period
        await checkAndCreateSnapshot(settings: settings, currentPeriod: period)

        do {
            async let tripsFetch = shoppingTripRepository.fetchByPeriod(
                householdId: householdId, period: period
            )
            async let wasteFetch = wasteEventRepository.fetchByPeriod(
                householdId: householdId, period: period
            )
            async let snapshotsFetch = periodSnapshotRepository.fetchRecent(
                householdId: householdId, limit: 6
            )

            let (fetchedTrips, fetchedWaste, fetchedSnapshots) = try await (
                tripsFetch, wasteFetch, snapshotsFetch
            )

            trips = fetchedTrips
            wasteEvents = fetchedWaste
            historicalSnapshots = fetchedSnapshots
        } catch {
            ToastManager.shared.show("Failed to load finance data", style: .error)
        }

        isLoading = false
    }

    // MARK: - Retroactive Cost Entry

    func saveRetroactiveCost(trip: ShoppingTrip? = nil, costText: String? = nil) async {
        let text = costText ?? retroactiveCostText
        guard var tripToSave = trip ?? tripToLog,
              let amount = Double(text), amount > 0 else {
            ToastManager.shared.show("Enter a valid amount", style: .error)
            return
        }

        tripToSave.totalCostMinor = Int(amount * 100)
        tripToSave.costLogged = true

        do {
            let updated = try await shoppingTripRepository.update(tripToSave)
            if let index = trips.firstIndex(where: { $0.tripId == updated.tripId }) {
                trips[index] = updated
            }
            ToastManager.shared.show("Cost saved", style: .success)
        } catch {
            ToastManager.shared.show("Failed to save cost", style: .error)
        }

        tripToLog = nil
        retroactiveCostText = ""
    }

    // MARK: - Manual Purchase Logging

    func logManualPurchase(amountMinor: Int, date: Date, storeName: String? = nil) async throws {
        let period = computePeriod(for: date)
        let trip = ShoppingTrip(
            tripId: UUID(),
            householdId: householdId,
            shoppingListId: nil,
            date: date,
            totalCostMinor: amountMinor,
            itemCount: 0,
            period: period,
            costLogged: true
        )
        _ = try await shoppingTripRepository.add(trip)
        ToastManager.shared.show("Purchase logged", style: .success)
        await loadData(forceRefresh: true)
    }

    // MARK: - Period Calculation

    func computeCurrentPeriod(settings: FinanceSettings) -> String {
        computePeriod(for: Date.now, budgetPeriod: settings.budgetPeriod)
    }

    private func computePeriod(for date: Date) -> String {
        let budgetPeriod = financeSettings?.budgetPeriod ?? .monthly
        return computePeriod(for: date, budgetPeriod: budgetPeriod)
    }

    private func computePeriod(for date: Date, budgetPeriod: BudgetPeriod) -> String {
        let calendar = Calendar.current
        switch budgetPeriod {
        case .weekly:
            let year = calendar.component(.yearForWeekOfYear, from: date)
            let week = calendar.component(.weekOfYear, from: date)
            return String(format: "%d-W%02d", year, week)
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
        }
    }
    // MARK: - Period Snapshots

    private func checkAndCreateSnapshot(settings: FinanceSettings, currentPeriod: String) async {
        let lastSnapshotKey = "lastSnapshotPeriod_\(householdId.uuidString)"
        let lastPeriod = UserDefaults.standard.string(forKey: lastSnapshotKey)

        // If we've never saved or the last saved period is different (and not current), save it
        guard let lastPeriod, lastPeriod != currentPeriod else {
            // First time or still same period — just record current
            UserDefaults.standard.set(currentPeriod, forKey: lastSnapshotKey)
            return
        }

        // A new period has begun — snapshot the previous one
        // Check if we already have a snapshot for that period
        if let _ = try? await periodSnapshotRepository.fetch(
            householdId: householdId, period: lastPeriod
        ) {
            UserDefaults.standard.set(currentPeriod, forKey: lastSnapshotKey)
            return
        }

        // Fetch previous period data to build snapshot
        do {
            let prevTrips = try await shoppingTripRepository.fetchByPeriod(
                householdId: householdId, period: lastPeriod
            )
            let prevWaste = try await wasteEventRepository.fetchByPeriod(
                householdId: householdId, period: lastPeriod
            )

            let totalSpent = prevTrips.compactMap(\.totalCostMinor).reduce(0, +)
            let totalWaste = prevWaste.compactMap(\.estimatedCostMinor).reduce(0, +)

            let snapshot = PeriodSnapshot(
                snapshotId: UUID(),
                householdId: householdId,
                period: lastPeriod,
                budgetAmountMinor: settings.budgetAmountMinor,
                totalSpentMinor: totalSpent,
                totalWasteMinor: totalWaste,
                wasteItemCount: prevWaste.count,
                tripCount: prevTrips.count,
                effectiveValueMinor: totalSpent - totalWaste
            )

            _ = try await periodSnapshotRepository.upsert(snapshot)
        } catch {
            // Snapshot creation is best-effort — don't block period transition
        }

        UserDefaults.standard.set(currentPeriod, forKey: lastSnapshotKey)
    }
}

enum BudgetHealthColor {
    case green, amber, red
}
