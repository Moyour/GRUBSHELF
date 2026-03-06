import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AddEditPantryItemViewModel {
    var name = ""
    var quantity = ""
    var selectedUnit: UnitType = .pcs
    var hasExpiry = false
    var expiryDate = Date.now.addingTimeInterval(7 * 24 * 60 * 60)
    var category = "Other"
    var customCategory = ""
    var validationErrors: [String] = []
    var isLoading = false
    var errorMessage: String?

    let isEditing: Bool
    private let existingItem: PantryItem?
    private let repository: PantryRepository
    private let householdId: UUID
    private let userId: UUID

    static let predefinedCategories = [
        "Fruits", "Vegetables", "Dairy", "Meat", "Seafood",
        "Grains", "Snacks", "Beverages", "Frozen", "Condiments",
        "African Staples", "African Spices", "Other"
    ]

    var resolvedCategory: String {
        category == "Custom" ? customCategory : category
    }

    init(
        repository: PantryRepository,
        householdId: UUID,
        userId: UUID,
        existingItem: PantryItem? = nil,
        catalogItem: GroceryCatalogItem? = nil,
        prefillFrom: PantryItem? = nil
    ) {
        self.repository = repository
        self.householdId = householdId
        self.userId = userId
        self.existingItem = existingItem
        self.isEditing = existingItem != nil

        if let item = existingItem {
            name = item.name
            quantity = String(item.quantity)
            selectedUnit = item.unit
            category = Self.predefinedCategories.contains(item.category) ? item.category : "Custom"
            customCategory = Self.predefinedCategories.contains(item.category) ? "" : item.category
            if let expiry = item.expiryDate {
                hasExpiry = true
                expiryDate = expiry
            }
        } else if let catalogItem {
            prefillFromCatalog(catalogItem)
        } else if let prefillFrom {
            name = prefillFrom.name
            quantity = String(prefillFrom.quantity)
            selectedUnit = prefillFrom.unit
            if Self.predefinedCategories.contains(prefillFrom.category) {
                category = prefillFrom.category
            } else {
                category = "Custom"
                customCategory = prefillFrom.category
            }
        }
    }

    func prefillFromCatalog(_ item: GroceryCatalogItem) {
        name = item.name
        selectedUnit = item.defaultUnit
        let cat = item.defaultCategory
        if Self.predefinedCategories.contains(cat) {
            category = cat
        } else {
            category = "Custom"
            customCategory = cat
        }
    }

    func validate() -> Bool {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespaces).isEmpty || name.count > 120 {
            errors.append("Name must be 1–120 characters.")
        }

        let qty = Double(quantity) ?? -1
        if qty <= 0 || qty > 1_000_000 {
            errors.append("Quantity must be between 0 and 1,000,000.")
        }

        let cat = resolvedCategory
        if cat.trimmingCharacters(in: .whitespaces).isEmpty || cat.count > 40 {
            errors.append("Category must be 1–40 characters.")
        }

        if hasExpiry && expiryDate > Date.now.addingTimeInterval(5 * 365.25 * 24 * 60 * 60) {
            errors.append("Expiry date must be within 5 years.")
        }

        validationErrors = errors
        if !errors.isEmpty {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        return errors.isEmpty
    }

    func save() async -> Bool {
        guard validate() else { return false }

        isLoading = true
        errorMessage = nil

        let parsedQuantity = Double(quantity) ?? 1

        do {
            if isEditing, var item = existingItem {
                item.name = name.trimmingCharacters(in: .whitespaces)
                item.quantity = parsedQuantity
                item.unit = selectedUnit
                item.category = resolvedCategory
                item.expiryDate = hasExpiry ? expiryDate : nil
                item.updatedAt = .now
                _ = try await withRetry { [repository] in try await repository.update(item) }
            } else {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let existing = try await repository.fetchAll(householdId: householdId)
                let match = existing.first { item in
                    !item.archived &&
                    item.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
                    item.unit == selectedUnit &&
                    item.expiryDate == nil && !hasExpiry
                }

                if var matched = match {
                    matched.quantity += parsedQuantity
                    matched.updatedAt = .now
                    _ = try await withRetry { [repository] in try await repository.update(matched) }
                } else {
                    let item = PantryItem(
                        itemId: UUID(),
                        householdId: householdId,
                        name: trimmedName,
                        quantity: parsedQuantity,
                        unit: selectedUnit,
                        category: resolvedCategory,
                        expiryDate: hasExpiry ? expiryDate : nil,
                        costPerUnitMinor: nil,
                        lowStockThreshold: 1,
                        createdBy: userId,
                        createdAt: .now,
                        updatedAt: .now,
                        archived: false,
                        lastQuantityUpdateDate: .now,
                        expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: resolvedCategory)
                    )
                    #if DEBUG
                    print("🛒 [PANTRY] Inserting item. created_by = \(userId), household_id = \(householdId)")
                    #endif
                    _ = try await withRetry { [repository] in try await repository.add(item) }
                }
            }

            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            let toastText = isEditing ? "\(name) updated" : "\(name) added to pantry"
            ToastManager.shared.show(toastText, style: .success)

            isLoading = false
            return true
        } catch {
            #if DEBUG
            print("🛒 [PANTRY] INSERT FAILED: \(error)")
            #endif
            errorMessage = error.localizedDescription
            ToastManager.shared.show("Failed to save item", style: .error)
            isLoading = false
            return false
        }
    }
}
