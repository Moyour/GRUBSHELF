import Foundation
import Observation

@MainActor
@Observable
final class PendingApprovalsViewModel {
    var pendingPantryItems: [PantryItem] = []
    var pendingShoppingItems: [ShoppingItem] = []
    var isLoading = false

    /// IDs of items currently being approved or rejected.
    private(set) var inflightItemIds: Set<UUID> = []
    /// True while bulk-approve-all-pantry is in progress.
    private(set) var isApprovingAllPantry = false
    /// True while bulk-approve-all-shopping is in progress.
    private(set) var isApprovingAllShopping = false

    private let pantryRepository: PantryRepository
    private let shoppingRepository: ShoppingRepository
    private let approvalService: ApprovalService
    private let householdId: UUID

    init(
        pantryRepository: PantryRepository = SupabasePantryRepository(),
        shoppingRepository: ShoppingRepository = SupabaseShoppingRepository(),
        approvalService: ApprovalService = ApprovalService(),
        householdId: UUID
    ) {
        self.pantryRepository = pantryRepository
        self.shoppingRepository = shoppingRepository
        self.approvalService = approvalService
        self.householdId = householdId
    }

    var totalPendingCount: Int {
        pendingPantryItems.count + pendingShoppingItems.count
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let pantryFetch = pantryRepository.fetchAll(householdId: householdId)
            async let shoppingFetch = shoppingRepository.fetchAll(householdId: householdId)
            let (pantry, shopping) = try await (pantryFetch, shoppingFetch)
            pendingPantryItems = pantry.filter { $0.approvalStatus == .pending }
            pendingShoppingItems = shopping.filter { $0.approvalStatus == .pending }
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "load pending approvals"),
                style: .error
            )
        }
    }

    func approvePantryItem(_ item: PantryItem) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            _ = try await approvalService.approvePantryItem(itemId: item.itemId)
            pendingPantryItems.removeAll { $0.itemId == item.itemId }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            ToastManager.shared.show("\(item.name) approved", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve \(item.name)"),
                style: .error
            )
        }
    }

    func rejectPantryItem(_ item: PantryItem, reason: String? = nil) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            _ = try await approvalService.rejectPantryItem(itemId: item.itemId, reason: reason)
            pendingPantryItems.removeAll { $0.itemId == item.itemId }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            ToastManager.shared.show("\(item.name) rejected", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "reject \(item.name)"),
                style: .error
            )
        }
    }

    func approveShoppingItem(_ item: ShoppingItem) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            _ = try await approvalService.approveShoppingItem(itemId: item.itemId)
            pendingShoppingItems.removeAll { $0.itemId == item.itemId }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            ToastManager.shared.show("\(item.name) approved", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve \(item.name)"),
                style: .error
            )
        }
    }

    func rejectShoppingItem(_ item: ShoppingItem, reason: String? = nil) async {
        guard inflightItemIds.insert(item.itemId).inserted else { return }
        defer { inflightItemIds.remove(item.itemId) }
        do {
            _ = try await approvalService.rejectShoppingItem(itemId: item.itemId, reason: reason)
            pendingShoppingItems.removeAll { $0.itemId == item.itemId }
            ApprovalNotificationCoordinator.shared.clearNotified(item.itemId)
            ToastManager.shared.show("\(item.name) rejected", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "reject \(item.name)"),
                style: .error
            )
        }
    }

    func approveAllPantry() async {
        guard !isApprovingAllPantry else { return }
        isApprovingAllPantry = true
        defer { isApprovingAllPantry = false }
        let ids = pendingPantryItems.map(\.itemId)
        guard !ids.isEmpty else { return }
        do {
            let count = try await approvalService.bulkApprovePantryItems(itemIds: ids)
            ids.forEach { ApprovalNotificationCoordinator.shared.clearNotified($0) }
            pendingPantryItems.removeAll()
            ToastManager.shared.show("Approved \(count) pantry item\(count == 1 ? "" : "s")", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve pantry items"),
                style: .error
            )
        }
    }

    func approveAllShopping() async {
        guard !isApprovingAllShopping else { return }
        isApprovingAllShopping = true
        defer { isApprovingAllShopping = false }
        let ids = pendingShoppingItems.map(\.itemId)
        guard !ids.isEmpty else { return }
        do {
            let count = try await approvalService.bulkApproveShoppingItems(itemIds: ids)
            ids.forEach { ApprovalNotificationCoordinator.shared.clearNotified($0) }
            pendingShoppingItems.removeAll()
            ToastManager.shared.show("Approved \(count) shopping item\(count == 1 ? "" : "s")", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "approve shopping items"),
                style: .error
            )
        }
    }
}
