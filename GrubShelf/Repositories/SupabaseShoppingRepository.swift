import Foundation
import os
import Supabase

private func isMissingShoppingApprovalColumnError(_ error: Error) -> Bool {
    guard let pg = error as? PostgrestError else { return false }
    guard pg.code == "PGRST204" else { return false }
    return pg.message.localizedCaseInsensitiveContains("approval_status")
}

private func isMissingShoppingCatalogIdColumnError(_ error: Error) -> Bool {
    guard let pg = error as? PostgrestError else { return false }
    guard pg.code == "PGRST204" else { return false }
    return pg.message.localizedCaseInsensitiveContains("catalog_item_id")
}

/// Insert-only payload that omits `transferred` (uses DB default).
private struct ShoppingItemInsert: Encodable {
        let itemId: UUID
        let householdId: UUID
        let listId: UUID?
        let name: String
        let quantity: Double
        let unit: UnitType?
        let category: String?
        let completed: Bool
        let createdBy: UUID
        let createdAt: Date
        let updatedAt: Date
        let approvalStatus: ApprovalStatus
        let catalogItemId: UUID?

        enum CodingKeys: String, CodingKey {
            case itemId = "item_id"
            case householdId = "household_id"
            case listId = "list_id"
            case name, quantity, unit, category, completed
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case approvalStatus = "approval_status"
            case catalogItemId = "catalog_item_id"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(itemId, forKey: .itemId)
            try container.encode(householdId, forKey: .householdId)
            try container.encodeIfPresent(listId, forKey: .listId)
            try container.encode(name, forKey: .name)
            try container.encode(quantity, forKey: .quantity)
            try container.encodeIfPresent(unit, forKey: .unit)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encode(completed, forKey: .completed)
            try container.encode(createdBy, forKey: .createdBy)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(approvalStatus, forKey: .approvalStatus)
            try container.encodeIfPresent(catalogItemId, forKey: .catalogItemId)
        }
}

/// Update-only payload — omits immutable fields and `transferred`.
private struct ShoppingItemUpdate: Encodable {
        let name: String
        let quantity: Double
        let unit: UnitType?
        let category: String?
        let completed: Bool
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case name, quantity, unit, category, completed
            case updatedAt = "updated_at"
        }
}

/// Transfer-specific payload — only sets transferred flag.
private struct ShoppingItemTransferUpdate: Encodable {
        let transferred: Bool
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case transferred
            case updatedAt = "updated_at"
        }
}

final class SupabaseShoppingRepository: ShoppingRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchAll(householdId: UUID) async throws -> [ShoppingItem] {
        try await withRetry { [client] in
            try await client.from("shopping_items")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .execute()
                .value
        }
    }

    func fetchByList(listId: UUID) async throws -> [ShoppingItem] {
        try await withRetry { [client] in
            try await client.from("shopping_items")
                .select()
                .eq("list_id", value: listId.uuidString)
                .execute()
                .value
        }
    }

    func add(_ item: ShoppingItem) async throws -> ShoppingItem {
        do {
            return try await insertShoppingItem(item, includeApprovalStatus: true)
        } catch {
            if isMissingShoppingCatalogIdColumnError(error), item.catalogItemId != nil {
                throw NSError(
                    domain: "GrubShelf.ShoppingRepository",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Shopping list catalog links are not available yet. Apply database migration 068_shopping_items_catalog_id, then try again."
                    ]
                )
            }
            if isMissingShoppingCatalogIdColumnError(error) {
                var fallback = item
                fallback.catalogItemId = nil
                return try await insertShoppingItem(fallback, includeApprovalStatus: true)
            }
            if isMissingShoppingApprovalColumnError(error) {
                return try await insertShoppingItem(item, includeApprovalStatus: false)
            }
            throw error
        }
    }

    private func insertShoppingItem(_ item: ShoppingItem, includeApprovalStatus: Bool) async throws -> ShoppingItem {
        if includeApprovalStatus {
            let insert = ShoppingItemInsert(
                itemId: item.itemId,
                householdId: item.householdId,
                listId: item.listId,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                category: item.category,
                completed: item.completed,
                createdBy: item.createdBy,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                approvalStatus: item.approvalStatus,
                catalogItemId: item.catalogItemId
            )
            return try await withRetry { [client] in
                try await client.from("shopping_items")
                    .insert(insert)
                    .select()
                    .single()
                    .execute()
                    .value
            }
        }

        struct LegacyInsert: Encodable {
            let itemId: UUID
            let householdId: UUID
            let listId: UUID?
            let name: String
            let quantity: Double
            let unit: UnitType?
            let category: String?
            let completed: Bool
            let createdBy: UUID
            let createdAt: Date
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case householdId = "household_id"
                case listId = "list_id"
                case name, quantity, unit, category, completed
                case createdBy = "created_by"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }

        let legacy = LegacyInsert(
            itemId: item.itemId,
            householdId: item.householdId,
            listId: item.listId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            completed: item.completed,
            createdBy: item.createdBy,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        return try await withRetry { [client] in
            try await client.from("shopping_items")
                .insert(legacy)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func update(_ item: ShoppingItem) async throws -> ShoppingItem {
        let payload = ShoppingItemUpdate(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            completed: item.completed,
            updatedAt: item.updatedAt
        )
        return try await withRetry { [client] in
            try await client.from("shopping_items")
                .update(payload)
                .eq("item_id", value: item.itemId.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func markTransferred(itemId: UUID) async throws -> ShoppingItem {
        let payload = ShoppingItemTransferUpdate(
            transferred: true,
            updatedAt: .now
        )
        return try await withRetry { [client] in
            try await client.from("shopping_items")
                .update(payload)
                .eq("item_id", value: itemId.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func delete(itemId: UUID) async throws {
        _ = try await withRetry { [client] in
            try await client.from("shopping_items")
                .delete()
                .eq("item_id", value: itemId.uuidString)
                .execute()
        }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[ShoppingItem]> {
        observeWithDebounce(
            client: client,
            channelName: "shopping_\(householdId.uuidString)",
            table: "shopping_items",
            filterColumn: "household_id",
            filterValue: householdId,
            logCategory: "ShoppingItems"
        ) { [self] in
            try await fetchAll(householdId: householdId)
        }
    }

    func observeListChanges(listId: UUID) -> AsyncStream<[ShoppingItem]> {
        observeWithDebounce(
            client: client,
            channelName: "shopping_list_\(listId.uuidString)",
            table: "shopping_items",
            filterColumn: "list_id",
            filterValue: listId.uuidString,
            logCategory: "ShoppingItems"
        ) { [self] in
            try await fetchByList(listId: listId)
        }
    }
}
