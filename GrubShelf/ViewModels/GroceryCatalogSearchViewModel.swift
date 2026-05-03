import Foundation
import Observation

@MainActor
@Observable
final class GroceryCatalogSearchViewModel {
    var searchText: String = ""
    var results: [GroceryCatalogItem] = []
    var isSearching = false
    var errorMessage: String?

    private let repository: GroceryCatalogRepository
    private var searchTask: Task<Void, Never>?

    init(repository: GroceryCatalogRepository) {
        self.repository = repository
    }

    func performSearch() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let items = try await repository.search(query: query, limit: 20)
                guard !Task.isCancelled else { return }
                results = items
                errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    func clear() {
        searchText = ""
        results = []
        isSearching = false
        errorMessage = nil
        searchTask?.cancel()
    }
}
