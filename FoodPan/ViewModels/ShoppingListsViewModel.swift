import Foundation
import Observation

@MainActor
@Observable
final class ShoppingListsViewModel {
    var lists: [ShoppingList] = []
    var hasLoaded = false
    var showCreateSheet = false
    var newListName: String = ""
    var listItemCounts: [UUID: (pending: Int, completed: Int)] = [:]
    var errorMessage: String?

    private let listRepository: ShoppingListRepository
    private let shoppingRepository: ShoppingRepository
    let householdId: UUID
    let userId: UUID
    private var observationTask: Task<Void, Never>?
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    init(
        listRepository: ShoppingListRepository,
        shoppingRepository: ShoppingRepository,
        householdId: UUID,
        userId: UUID
    ) {
        self.listRepository = listRepository
        self.shoppingRepository = shoppingRepository
        self.householdId = householdId
        self.userId = userId
    }

    func loadLists(forceRefresh: Bool = false) async {
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        do {
            lists = try await listRepository.fetchAll(householdId: householdId)
            await loadItemCounts()
            hasLoaded = true
            lastLoadedAt = .now
        } catch {
            hasLoaded = true
            switch ErrorHandler.classify(error) {
            case .networkFailure:
                ToastManager.shared.show("You're offline — showing cached data", style: .error)
            case .serverError:
                ToastManager.shared.show("Server is temporarily unavailable", style: .error)
            default:
                errorMessage = "Failed to load lists: \(error.localizedDescription)"
            }
        }
    }

    private func loadItemCounts() async {
        do {
            let allItems = try await shoppingRepository.fetchAll(householdId: householdId)
            var counts: [UUID: (pending: Int, completed: Int)] = [:]
            for item in allItems {
                guard let listId = item.listId else { continue }
                let current = counts[listId] ?? (pending: 0, completed: 0)
                if item.completed {
                    counts[listId] = (pending: current.pending, completed: current.completed + 1)
                } else {
                    counts[listId] = (pending: current.pending + 1, completed: current.completed)
                }
            }
            listItemCounts = counts
        } catch {
            // Non-critical — item counts are supplementary, list still displays
        }
    }

    func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let list = ShoppingList(
            listId: UUID(),
            householdId: householdId,
            name: name,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )

        newListName = ""
        errorMessage = nil

        do {
            let saved = try await listRepository.add(list)
            lists.insert(saved, at: 0)
            ToastManager.shared.show("\(saved.name) created", style: .success)
        } catch {
            errorMessage = "Failed to create list: \(error.localizedDescription)"
            ToastManager.shared.show("Failed to create list", style: .error)
        }
    }

    func deleteList(_ list: ShoppingList) async {
        do {
            try await listRepository.delete(listId: list.listId)
            lists.removeAll { $0.listId == list.listId }
            listItemCounts.removeValue(forKey: list.listId)
            ToastManager.shared.show("\(list.name) deleted", style: .success)
        } catch {
            errorMessage = "Failed to delete list: \(error.localizedDescription)"
            ToastManager.shared.show("Failed to delete list", style: .error)
        }
    }

    func startObserving() {
        observationTask = Task {
            for await updated in listRepository.observeChanges(householdId: householdId) {
                self.lists = updated
                await self.loadItemCounts()
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}
