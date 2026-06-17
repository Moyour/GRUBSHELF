import Foundation
import Supabase

struct PendingApprovalCounts: Codable, Sendable, Equatable {
    let pendingPantryCount: Int
    let pendingShoppingCount: Int

    var total: Int { pendingPantryCount + pendingShoppingCount }

    enum CodingKeys: String, CodingKey {
        case pendingPantryCount = "pending_pantry_count"
        case pendingShoppingCount = "pending_shopping_count"
    }
}

final class ApprovalService: Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func approvePantryItem(itemId: UUID) async throws -> PantryItem {
        let rows: [PantryItem] = try await withRetry { [client] in
            try await client.rpc(
                "approve_pantry_item",
                params: ["p_item_id": itemId.uuidString]
            ).execute().value
        }
        guard let item = rows.first else {
            throw ApprovalServiceError.emptyResponse
        }
        return item
    }

    func rejectPantryItem(itemId: UUID, reason: String? = nil) async throws -> PantryItem {
        let params: [String: String]
        if let reason, !reason.isEmpty {
            params = ["p_item_id": itemId.uuidString, "p_reason": reason]
        } else {
            params = ["p_item_id": itemId.uuidString]
        }
        let rows: [PantryItem] = try await withRetry { [client] in
            try await client.rpc("reject_pantry_item", params: params)
                .execute().value
        }
        guard let item = rows.first else {
            throw ApprovalServiceError.emptyResponse
        }
        return item
    }

    func approveShoppingItem(itemId: UUID) async throws -> ShoppingItem {
        let rows: [ShoppingItem] = try await withRetry { [client] in
            try await client.rpc(
                "approve_shopping_item",
                params: ["p_item_id": itemId.uuidString]
            ).execute().value
        }
        guard let item = rows.first else {
            throw ApprovalServiceError.emptyResponse
        }
        return item
    }

    func rejectShoppingItem(itemId: UUID, reason: String? = nil) async throws -> ShoppingItem {
        let params: [String: String]
        if let reason, !reason.isEmpty {
            params = ["p_item_id": itemId.uuidString, "p_reason": reason]
        } else {
            params = ["p_item_id": itemId.uuidString]
        }
        let rows: [ShoppingItem] = try await withRetry { [client] in
            try await client.rpc("reject_shopping_item", params: params)
                .execute().value
        }
        guard let item = rows.first else {
            throw ApprovalServiceError.emptyResponse
        }
        return item
    }

    func fetchPendingCounts(householdId: UUID) async throws -> PendingApprovalCounts {
        let rows: [PendingApprovalCounts] = try await client.rpc(
            "get_pending_approvals_count",
            params: ["p_household_id": householdId.uuidString]
        ).execute().value
        return rows.first ?? PendingApprovalCounts(pendingPantryCount: 0, pendingShoppingCount: 0)
    }

    func bulkApprovePantryItems(itemIds: [UUID]) async throws -> Int {
        let ids = itemIds.map(\.uuidString)
        let count: Int = try await client.rpc(
            "bulk_approve_pantry_items",
            params: ["p_item_ids": ids]
        ).execute().value
        return count
    }

    func bulkApproveShoppingItems(itemIds: [UUID]) async throws -> Int {
        let ids = itemIds.map(\.uuidString)
        let count: Int = try await client.rpc(
            "bulk_approve_shopping_items",
            params: ["p_item_ids": ids]
        ).execute().value
        return count
    }
}

enum ApprovalServiceError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse: "No item returned from the server."
        }
    }
}
