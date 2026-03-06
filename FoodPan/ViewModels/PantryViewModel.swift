import Foundation
import Observation
import SwiftUI

enum PantryFilter: String, CaseIterable {
    case all = "All"
    case expiring = "Expiring"
    case lowStock = "Low Stock"
    case categories = "Categories"
}

@MainActor
@Observable
final class PantryViewModel {
    var items: [PantryItem] = []
    var hasLoaded = false
    var selectedFilter: PantryFilter = .all
    var searchText: String = ""
    var itemToEdit: PantryItem?
    var showAddSheet = false
    var showRemovalPrompt = false
    var showWasteCostPrompt = false
    var itemToRemove: PantryItem?
    var wasteCostText = ""

    let repository: PantryRepository
    let householdId: UUID
    let userId: UUID
    private let wasteEventRepository: WasteEventRepository
    private let financeSettingsRepository: FinanceSettingsRepository
    private var observationTask: Task<Void, Never>?
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    var filteredItems: [PantryItem] {
        var result = items

        switch selectedFilter {
        case .all:
            break
        case .expiring:
            result = result.filter { $0.state == .expiringSoon || $0.state == .expired }
        case .lowStock:
            result = result.filter { $0.state == .lowStock }
        case .categories:
            break // handled by groupedByCategory
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var groupedByCategory: [(category: String, items: [PantryItem])] {
        let filtered = searchText.isEmpty ? items : items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
        let grouped = Dictionary(grouping: filtered) { $0.category }
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
            lastLoadedAt = .now
        } catch {
            hasLoaded = true
            switch ErrorHandler.classify(error) {
            case .networkFailure:
                ToastManager.shared.show("You're offline — showing cached data", style: .error)
            case .serverError:
                ToastManager.shared.show("Server is temporarily unavailable", style: .error)
            default:
                ToastManager.shared.show("Failed to load pantry items", style: .error)
            }
        }
    }

    func startObserving() {
        observationTask = Task {
            for await updated in repository.observeChanges(householdId: householdId) {
                guard !Task.isCancelled else { return }
                withAnimation {
                    self.items = updated
                }
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
            ToastManager.shared.show("Failed to delete \(item.name)", style: .error)
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
        stopObserving()
        do {
            let saved = try await withRetry { [repository] in try await repository.update(updated) }
            withAnimation {
                items[index] = saved
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
        } catch {
            ToastManager.shared.show("Failed to update \(item.name)", style: .error)
        }
        resumeObserving()
    }

    // MARK: - Quick Decrement

    func decrementItem(_ item: PantryItem, by amount: Double = 1) async {
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = items[index]
        updated.quantity = max(0, updated.quantity - amount)
        updated.updatedAt = .now
        updated.lastQuantityUpdateDate = .now
        stopObserving()
        do {
            let saved = try await withRetry { [repository] in try await repository.update(updated) }
            withAnimation {
                items[index] = saved
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if saved.quantity <= 0 {
                itemToRemove = saved
                showRemovalPrompt = true
            } else {
                ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
            }
        } catch {
            ToastManager.shared.show("Failed to update \(item.name)", style: .error)
        }
        resumeObserving()
    }

    func halveItem(_ item: PantryItem) async {
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId }) else { return }
        var updated = items[index]
        updated.quantity = max(0, (updated.quantity / 2).rounded(.down))
        updated.updatedAt = .now
        updated.lastQuantityUpdateDate = .now
        stopObserving()
        do {
            let saved = try await withRetry { [repository] in try await repository.update(updated) }
            withAnimation {
                items[index] = saved
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if saved.quantity <= 0 {
                itemToRemove = saved
                showRemovalPrompt = true
            } else {
                ToastManager.shared.show("\(saved.name) → \(saved.quantity.formatted()) \(saved.unit.abbreviation)", style: .success)
            }
        } catch {
            ToastManager.shared.show("Failed to update \(item.name)", style: .error)
        }
        resumeObserving()
    }

    func markFinished(_ item: PantryItem) {
        itemToRemove = item
        showRemovalPrompt = true
    }

    // MARK: - Waste Tracking

    func confirmUsed() async {
        guard let item = itemToRemove else { return }
        await deleteItem(item)
        itemToRemove = nil
    }

    func confirmWasted() {
        showWasteCostPrompt = true
    }

    func saveWasteEvent(skipCost: Bool = false) async {
        guard let item = itemToRemove else { return }

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
            source: "manual_removal"
        )

        do {
            _ = try await wasteEventRepository.add(event)
        } catch {
            ToastManager.shared.show("Waste event not saved", style: .error)
        }

        await deleteItem(item)
        itemToRemove = nil
        wasteCostText = ""
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
