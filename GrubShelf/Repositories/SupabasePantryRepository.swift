import Foundation
import os
import Supabase

/// PostgREST sometimes rejects `storage_location` on `pantry_items` (PGRST204) when the column is missing or the schema cache is stale. Helpers encode rows and strip that key for a retry.
enum PantrySupabaseWriteSupport {
    static func isMissingStorageLocationColumnError(_ error: Error) -> Bool {
        guard let pg = error as? PostgrestError else { return false }
        guard pg.code == "PGRST204" else { return false }
        return pg.message.localizedCaseInsensitiveContains("storage_location")
    }

    static func isMissingApprovalColumnError(_ error: Error) -> Bool {
        guard let pg = error as? PostgrestError else { return false }
        guard pg.code == "PGRST204" else { return false }
        let message = pg.message.lowercased()
        return message.contains("approval_status")
            || message.contains("approved_by")
            || message.contains("approved_at")
            || message.contains("rejection_reason")
    }

    static func withoutApprovalFields(_ row: JSONObject) -> JSONObject {
        var copy = row
        copy.removeValue(forKey: "approval_status")
        copy.removeValue(forKey: "approved_by")
        copy.removeValue(forKey: "approved_at")
        copy.removeValue(forKey: "rejection_reason")
        return copy
    }

    static func pantryInsertRow(_ item: PantryItem, includeStorageLocation: Bool, includeApprovalFields: Bool) throws -> JSONObject {
        var obj = try pantryInsertRow(item, includeStorageLocation: includeStorageLocation)
        if !includeApprovalFields {
            obj = withoutApprovalFields(obj)
        }
        return obj
    }

    static func jsonObject(from encodable: some Encodable) throws -> JSONObject {
        let encoder = PostgrestClient.Configuration.jsonEncoder
        let decoder = PostgrestClient.Configuration.jsonDecoder
        let data = try encoder.encode(encodable)
        return try decoder.decode(JSONObject.self, from: data)
    }

    static func withoutStorageLocation(_ row: JSONObject) -> JSONObject {
        var copy = row
        copy.removeValue(forKey: "storage_location")
        return copy
    }

    static func pantryInsertRow(_ item: PantryItem, includeStorageLocation: Bool) throws -> JSONObject {
        var obj = try jsonObject(from: item)
        if !includeStorageLocation {
            obj.removeValue(forKey: "storage_location")
        }
        return obj
    }
}

/// PATCH body for `pantry_items`: omit immutable / identity columns (`item_id`, `household_id`,
/// `created_by`, `created_at`). PostgREST applies the filter on `item_id`; keeping those keys out
/// of the JSON avoids edge cases with primary keys and audit columns on some deployments.
private struct PantryItemUpdateBody: Encodable {
    let name: String
    let quantity: Double
    let unit: UnitType
    let category: String
    let storageLocation: PantryStorageLocation
    let expiryDate: Date?
    let costPerUnitMinor: Int?
    let lowStockThreshold: Double
    let updatedAt: Date
    let archived: Bool
    let lastQuantityUpdateDate: Date?
    let expectedUsageCycleDays: Int?
    let reminderStatus: ReminderStatus
    let reminderSnoozedUntil: Date?
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit, category
        case storageLocation = "storage_location"
        case expiryDate = "expiry_date"
        case costPerUnitMinor = "cost_per_unit_minor"
        case lowStockThreshold = "low_stock_threshold"
        case updatedAt = "updated_at"
        case archived
        case lastQuantityUpdateDate = "last_quantity_update_date"
        case expectedUsageCycleDays = "expected_usage_cycle_days"
        case reminderStatus = "reminder_status"
        case reminderSnoozedUntil = "reminder_snoozed_until"
        case photoPath = "photo_path"
    }

    init(_ item: PantryItem) {
        name = item.name
        quantity = item.quantity
        unit = item.unit
        category = item.category
        storageLocation = item.storageLocation
        expiryDate = item.expiryDate
        costPerUnitMinor = item.costPerUnitMinor
        lowStockThreshold = item.lowStockThreshold
        updatedAt = item.updatedAt
        archived = item.archived
        lastQuantityUpdateDate = item.lastQuantityUpdateDate
        expectedUsageCycleDays = item.expectedUsageCycleDays
        reminderStatus = item.reminderStatus
        reminderSnoozedUntil = item.reminderSnoozedUntil
        photoPath = item.photoPath
    }
}

final class SupabasePantryRepository: PantryRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchAll(householdId: UUID) async throws -> [PantryItem] {
        try await withRetry { [client] in
            try await client.from("pantry_items")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .eq("archived", value: false)
                .execute()
                .value
        }
    }

    func add(_ item: PantryItem) async throws -> PantryItem {
        do {
            return try await insertPantryItem(item, includeStorageLocation: true, includeApprovalFields: true)
        } catch {
            if PantrySupabaseWriteSupport.isMissingStorageLocationColumnError(error) {
                return try await insertPantryItem(item, includeStorageLocation: false, includeApprovalFields: true)
            }
            if PantrySupabaseWriteSupport.isMissingApprovalColumnError(error) {
                return try await insertPantryItem(item, includeStorageLocation: true, includeApprovalFields: false)
            }
            throw error
        }
    }

    func update(_ item: PantryItem) async throws -> PantryItem {
        do {
            return try await updatePantryItem(item, includeStorageLocation: true)
        } catch {
            if PantrySupabaseWriteSupport.isMissingStorageLocationColumnError(error) {
                return try await updatePantryItem(item, includeStorageLocation: false)
            }
            throw error
        }
    }

    private func insertPantryItem(
        _ item: PantryItem,
        includeStorageLocation: Bool,
        includeApprovalFields: Bool
    ) async throws -> PantryItem {
        if includeStorageLocation && includeApprovalFields {
            return try await withRetry { [client] in
                try await client.from("pantry_items")
                    .insert(item)
                    .select()
                    .single()
                    .execute()
                    .value
            }
        }
        let row = try PantrySupabaseWriteSupport.pantryInsertRow(
            item,
            includeStorageLocation: includeStorageLocation,
            includeApprovalFields: includeApprovalFields
        )
        return try await withRetry { [client] in
            try await client.from("pantry_items")
                .insert(row)
                .select()
                .single()
                .execute()
                .value
        }
    }

    private func updatePantryItem(_ item: PantryItem, includeStorageLocation: Bool) async throws -> PantryItem {
        if includeStorageLocation {
            return try await withRetry { [client] in
                try await client.from("pantry_items")
                    .update(PantryItemUpdateBody(item))
                    .eq("item_id", value: item.itemId.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value
            }
        }
        let row = PantrySupabaseWriteSupport.withoutStorageLocation(
            try PantrySupabaseWriteSupport.jsonObject(from: PantryItemUpdateBody(item))
        )
        return try await withRetry { [client] in
            try await client.from("pantry_items")
                .update(row)
                .eq("item_id", value: item.itemId.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func delete(itemId: UUID) async throws {
        _ = try await withRetry { [client] in
            try await client.from("pantry_items")
                .delete()
                .eq("item_id", value: itemId.uuidString)
                .execute()
        }
    }

    func observeChanges(householdId: UUID) -> AsyncStream<[PantryItem]> {
        observeWithDebounce(
            client: client,
            channelName: "pantry_\(householdId.uuidString)",
            table: "pantry_items",
            filterColumn: "household_id",
            filterValue: householdId,
            logCategory: "Pantry"
        ) { [self] in
            try await fetchAll(householdId: householdId)
        }
    }
}

// MARK: - Barcode labels (Supabase)

private struct BarcodeLabelUpsertPayload: Encodable {
    let householdId: UUID
    let barcode: String
    let displayName: String
    let category: String
    let catalogItemId: UUID?

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case barcode
        case displayName = "display_name"
        case category
        case catalogItemId = "catalog_item_id"
    }
}

final class SupabaseBarcodeLabelRepository: BarcodeLabelRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchLabel(householdId: UUID, barcode: String) async throws -> HouseholdBarcodeLabel? {
        do {
            return try await withRetry { [client] in
                try await client.from("household_barcode_labels")
                    .select()
                    .eq("household_id", value: householdId.uuidString)
                    .eq("barcode", value: barcode)
                    .single()
                    .execute()
                    .value
            }
        } catch {
            return nil
        }
    }

    func upsertLabel(
        householdId: UUID,
        barcode: String,
        displayName: String,
        category: String,
        catalogItemId: UUID?
    ) async throws {
        let row = BarcodeLabelUpsertPayload(
            householdId: householdId,
            barcode: barcode,
            displayName: displayName,
            category: category,
            catalogItemId: catalogItemId
        )
        _ = try await withRetry { [client] in
            try await client.from("household_barcode_labels")
                .upsert(row, onConflict: "household_id,barcode")
                .execute()
        }
    }
}

