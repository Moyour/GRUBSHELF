import Foundation
import Observation
import SwiftUI

// MARK: - Pantry browsing

enum PantryLocationFilter: String, CaseIterable {
    case all = "All"
    case fridge = "Fridge"
    case shelf = "Shelf"
}

enum PantryAttentionMode: Equatable {
    case none
    case expiring
    case lowStock
}

/// Deep-link / Home queue: which pantry segment and optional urgency filter to apply.
struct PantryNavigationFocus: Equatable {
    var locationFilter: PantryLocationFilter
    var attention: PantryAttentionMode

    static let lowStock = PantryNavigationFocus(locationFilter: .all, attention: .lowStock)
    static let expiring = PantryNavigationFocus(locationFilter: .all, attention: .expiring)
}

@MainActor
@Observable
final class PantryViewModel {
    var items: [PantryItem] = []
    var hasLoaded = false
    var selectedLocationFilter: PantryLocationFilter = .all
    var selectedAttention: PantryAttentionMode = .none
    var searchText: String = ""
    var confidenceScores: [UUID: Double] = [:]
    var itemToEdit: PantryItem?
    var showAddSheet = false
    var showRemovalPrompt = false
    var showWasteCostPrompt = false
    var itemToRemove: PantryItem?
    var wasteCostText = ""
    private var pendingWasteSource: WasteEventSource?

    let repository: PantryRepository
    let householdId: UUID
    let userId: UUID
    private let wasteEventRepository: WasteEventRepository
    private let financeSettingsRepository: FinanceSettingsRepository
    private var observationTask: Task<Void, Never>?
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    /// Applies focus when opening Pantry from Home / notifications.
    func applyNavigationFocus(_ focus: PantryNavigationFocus) {
        selectedLocationFilter = focus.locationFilter
        selectedAttention = focus.attention
    }

    var filteredItems: [PantryItem] {
        var result = items

        switch selectedLocationFilter {
        case .all:
            break
        case .fridge:
            result = result.filter { $0.storageLocation == .fridge }
        case .shelf:
            result = result.filter { $0.storageLocation == .shelf }
        }

        switch selectedAttention {
        case .none:
            break
        case .expiring:
            result = result.filter { $0.state == .expiringSoon || $0.state == .expired }
        case .lowStock:
            result = result.filter { $0.state == .lowStock }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    func confidence(for item: PantryItem) -> Double {
        confidenceScores[item.itemId] ?? 1.0
    }

    var confidentFilteredItems: [PantryItem] {
        filteredItems.filter { confidence(for: $0) >= 0.3 }
    }

    var probablyGoneFilteredItems: [PantryItem] {
        filteredItems.filter { confidence(for: $0) < 0.3 }
    }

    /// Stale items that should appear in Pantry Review (same rule as dashboard card).
    var staleItemsForReview: [PantryItem] {
        items.filter { $0.state == .stale && !$0.archived }
    }

    // MARK: - Summary counts (Pantry header — matches Home “at a glance”)

    private var nonArchivedItems: [PantryItem] {
        items.filter { !$0.archived }
    }

    /// Active (non-archived) line items.
    var pantryTotalActiveCount: Int {
        nonArchivedItems.count
    }

    /// Expiring soon or already expired (non-archived).
    var pantryExpiringAttentionCount: Int {
        nonArchivedItems.filter { $0.state == .expiringSoon || $0.state == .expired }.count
    }

    /// Below minimum quantity (non-archived).
    var pantryLowStockAttentionCount: Int {
        nonArchivedItems.filter { $0.state == .lowStock }.count
    }

    /// Expiring or expired items for Home preview (soonest first, max five). Matches dashboard ordering.
    var homeExpiringPreviewItems: [PantryItem] {
        items
            .filter { !$0.archived && ($0.state == .expiringSoon || $0.state == .expired) }
            .sorted { lhs, rhs in
                (lhs.expiryDate ?? .distantFuture) < (rhs.expiryDate ?? .distantFuture)
            }
            .prefix(5)
            .map { $0 }
    }

    /// Grouped by category for the **All** location tab (browse by food type).
    var groupedFilteredByCategory: [(category: String, items: [PantryItem])] {
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return grouped.map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    init(
        repository: PantryRepository,
        householdId: UUID,
        userId: UUID,
        wasteEventRepository: WasteEventRepository = SupabaseWasteEventRepository(),
        financeSettingsRepository: FinanceSettingsRepository = SupabaseFinanceSettingsRepository()
    ) {
        self.repository = repository
        self.householdId = householdId
        self.userId = userId
        self.wasteEventRepository = wasteEventRepository
        self.financeSettingsRepository = financeSettingsRepository
    }

    func loadItems(forceRefresh: Bool = false) async {
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        do {
            let fetched = try await repository.fetchAll(householdId: householdId)
            withAnimation {
                items = fetched
                hasLoaded = true
            }
            computeConfidence()
            lastLoadedAt = .now
        } catch {
            hasLoaded = true
            switch ErrorHandler.classify(error) {
            case .networkFailure:
                ToastManager.shared.show("You’re offline—showing your last pantry snapshot", style: .error)
            case .serverError:
                ToastManager.shared.show("Can’t reach the server right now", style: .error)
            default:
                ToastManager.shared.show("Couldn’t load your pantry", style: .error)
            }
        }
    }

    func startObserving() {
        observationTask?.cancel()
        observationTask = Task {
            for await updated in repository.observeChanges(householdId: householdId) {
                guard !Task.isCancelled else { return }
                withAnimation {
                    self.items = updated
                }
                self.computeConfidence()
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// Restarts the observer after a brief delay to let SwiftUI finish processing animated changes.
    private func resumeObserving() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            startObserving()
        }
    }

    func deleteItem(_ item: PantryItem) async {
        stopObserving()
        do {
            try await withRetry { [repository] in
                try await repository.delete(itemId: item.itemId)
            }
            withAnimation {
                items.removeAll { $0.itemId == item.itemId }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            ToastManager.shared.show("\(item.name) deleted", style: .success)
        } catch {
            ToastManager.shared.show("Couldn’t delete \(item.name)", style: .error)
        }
        resumeObserving()
    }

    // MARK: - Quick Increment

    func incrementItem(_ item: PantryItem, by amount: Double = 1) async {
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = items[index]
        updated.quantity += amount
        updated.updatedAt = .now
        updated.lastQuantityUpdateDate = .now
        let capturedUpdate = updated
        // Optimistic UI update (observer stays running)
        withAnimation { items[index] = updated }
        do {
            let saved = try await withRetry { [repository] in try await repository.update(capturedUpdate) }
            if let i = items.firstIndex(where: { $0.itemId == saved.itemId }) {
                withAnimation { items[i] = saved }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
        } catch {
            // Rollback optimistic update
            if let i = items.firstIndex(where: { $0.itemId == item.itemId }) {
                withAnimation { items[i] = item }
            }
            ToastManager.shared.show("Couldn't save quantity for \(item.name)", style: .error)
        }
    }

    // MARK: - Quick Decrement

    func decrementItem(_ item: PantryItem, by amount: Double = 1) async {
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = items[index]
        updated.quantity = max(0, updated.quantity - amount)
        updated.updatedAt = .now
        updated.lastQuantityUpdateDate = .now
        let capturedUpdate = updated
        // Optimistic UI update (observer stays running)
        withAnimation { items[index] = updated }
        do {
            let saved = try await withRetry { [repository] in try await repository.update(capturedUpdate) }
            if let i = items.firstIndex(where: { $0.itemId == saved.itemId }) {
                withAnimation { items[i] = saved }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if saved.quantity <= 0 {
                itemToRemove = saved
                showRemovalPrompt = true
            } else {
                ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
            }
        } catch {
            // Rollback optimistic update
            if let i = items.firstIndex(where: { $0.itemId == item.itemId }) {
                withAnimation { items[i] = item }
            }
            ToastManager.shared.show("Couldn't save quantity for \(item.name)", style: .error)
        }
    }

    func halveItem(_ item: PantryItem) async {
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = items[index]
        updated.quantity = max(0, (updated.quantity / 2).rounded(.down))
        updated.updatedAt = .now
        updated.lastQuantityUpdateDate = .now
        let capturedUpdate = updated
        // Optimistic UI update (observer stays running)
        withAnimation { items[index] = updated }
        do {
            let saved = try await withRetry { [repository] in try await repository.update(capturedUpdate) }
            if let i = items.firstIndex(where: { $0.itemId == saved.itemId }) {
                withAnimation { items[i] = saved }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if saved.quantity <= 0 {
                itemToRemove = saved
                showRemovalPrompt = true
            } else {
                ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
            }
        } catch {
            // Rollback optimistic update
            if let i = items.firstIndex(where: { $0.itemId == item.itemId }) {
                withAnimation { items[i] = item }
            }
            ToastManager.shared.show("Couldn't save quantity for \(item.name)", style: .error)
        }
    }

    func markFinished(_ item: PantryItem) {
        itemToRemove = item
        showRemovalPrompt = true
    }

    // MARK: - Waste Tracking

    func confirmUsed() async {
        guard let item = itemToRemove else { return }
        await deleteItem(item)
        clearRemovalFlowState()
    }

    func confirmRemoveFromList() async {
        guard let item = itemToRemove else { return }
        await deleteItem(item)
        clearRemovalFlowState()
    }

    func beginExpiredRemoval() {
        pendingWasteSource = .expired
        showWasteCostPrompt = true
    }

    func beginWasteRemoval() {
        pendingWasteSource = .waste
        showWasteCostPrompt = true
    }

    func saveWasteEvent(skipCost: Bool = false) async {
        guard let item = itemToRemove, let pendingWasteSource else { return }

        let costMinor: Int? = if skipCost {
            nil
        } else if let amount = Double(wasteCostText), amount > 0 {
            Int(amount * 100)
        } else {
            nil
        }

        let period = await computePeriodString()

        let event = WasteEvent(
            eventId: UUID(),
            householdId: householdId,
            pantryItemId: item.itemId,
            itemName: item.name,
            date: .now,
            estimatedCostMinor: costMinor,
            period: period,
            source: pendingWasteSource.rawValue
        )

        do {
            _ = try await wasteEventRepository.add(event)
        } catch {
            ToastManager.shared.show("Couldn’t save that waste note", style: .error)
        }

        await deleteItem(item)
        clearRemovalFlowState()
    }

    func cancelRemovalFlow() {
        clearRemovalFlowState()
    }

    private func clearRemovalFlowState() {
        itemToRemove = nil
        wasteCostText = ""
        pendingWasteSource = nil
    }

    private func computeConfidence() {
        var scores: [UUID: Double] = [:]
        for item in items {
            scores[item.itemId] = PantryConfidenceService.confidence(for: item)
        }
        confidenceScores = scores
    }

    private func computePeriodString() async -> String {
        let calendar = Calendar.current
        let now = Date.now

        if let settings = try? await financeSettingsRepository.fetch(userId: userId) {
            switch settings.budgetPeriod {
            case .weekly:
                let year = calendar.component(.yearForWeekOfYear, from: now)
                let week = calendar.component(.weekOfYear, from: now)
                return String(format: "%d-W%02d", year, week)
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: now)
                return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
            }
        }

        let comps = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%d-%02d", comps.year ?? 1970, comps.month ?? 1)
    }
}
