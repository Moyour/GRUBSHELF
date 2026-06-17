import Foundation
import Observation
import os
import SwiftUI
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
    var selectedStorageLocation: PantryStorageLocation = .shelf
    var validationErrors: [String] = []
    var isLoading = false
    var errorMessage: String?
    var isRecognizingFromPhoto = false
    /// Short hint after photo recognition (success tip or error).
    var photoRecognitionHint: String?
    var photoRecognitionHintIsError = false
    var recognizedPhotoPreview: UIImage?
    var lastRecognitionConfidence: Float?
    var lastRecognitionIsLikelyFood: Bool = true
    var photoRecognitionSuggestions: [String] = []
    /// When true, the success toast after save is suppressed (used by multi-add hub).
    var suppressToast = false
    /// The ID of the most recently saved new item (set after a successful add).
    private(set) var lastSavedItemId: UUID?
    /// The full PantryItem of the most recently saved new item.
    private(set) var lastSavedItem: PantryItem?

    let isEditing: Bool
    /// Exposes the item ID so the view can notify parents on deletion.
    var deletingItemId: UUID? { existingItem?.itemId }
    private let existingItem: PantryItem?
    private let repository: PantryRepository
    private let householdId: UUID
    private let userId: UUID
    private let userRole: UserRole

    private var insertsAsApproved: Bool { userRole == .admin }
    /// When set, successful save upserts household barcode → pantry label (scan flow).
    private let scannedBarcodeDigits: String?
    private let barcodeLabelRepository: BarcodeLabelRepository?
    private let photoStorage: PantryPhotoStorage
    /// Catalog row used for this add (from barcode match or search), for optional `catalog_item_id` on the label.
    private let catalogItemIdForBarcodeSave: UUID?
    /// Optional gate service for enforcing subscription limits on new items.
    @ObservationIgnored var featureGateService: FeatureGateService?
    /// Called after a successful new-item add with the created PantryItem.
    @ObservationIgnored var onSaveSuccess: ((PantryItem) -> Void)?
    private static let logger = Logger(subsystem: "com.grubshelf", category: "PantryEdit")
    private static let lowConfidenceThreshold: Float = 0.45

    static let predefinedCategories = [
        "Fruits", "Vegetables", "Dairy", "Meat", "Seafood",
        "Grains", "Snacks", "Beverages", "Frozen", "Condiments",
        "African Staples", "African Spices", "Other"
    ]

    var resolvedCategory: String {
        category == "Custom" ? customCategory : category
    }

    /// Badge status derived from the last photo-recognition result for the confidence UI.
    var recognitionBadgeStatus: StatusBadgeView.Status? {
        guard lastRecognitionConfidence != nil else { return nil }
        if !lastRecognitionIsLikelyFood {
            return .custom(label: "Not food?", icon: "questionmark.circle.fill", color: .gsWarning)
        }
        guard let c = lastRecognitionConfidence else { return nil }
        if c >= 0.7 {
            return .custom(label: "High confidence", icon: "checkmark.seal.fill", color: .gsSuccess)
        } else if c >= 0.45 {
            return .custom(label: "Medium confidence", icon: "exclamationmark.circle.fill", color: .gsWarning)
        } else {
            return .custom(label: "Low confidence", icon: "exclamationmark.triangle.fill", color: .gsDanger)
        }
    }

    init(
        repository: PantryRepository,
        householdId: UUID,
        userId: UUID,
        userRole: UserRole = .member,
        existingItem: PantryItem? = nil,
        catalogItem: GroceryCatalogItem? = nil,
        prefillFrom: PantryItem? = nil,
        barcodePrefillName: String? = nil,
        barcodePrefillCategory: String? = nil,
        scannedBarcodeDigits: String? = nil,
        barcodeLabelRepository: BarcodeLabelRepository? = nil,
        photoStorage: PantryPhotoStorage = SupabasePantryPhotoStorage(),
        barcodeNotFoundHint: String? = nil
    ) {
        self.repository = repository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
        self.existingItem = existingItem
        self.isEditing = existingItem != nil
        self.scannedBarcodeDigits = scannedBarcodeDigits
        self.barcodeLabelRepository = barcodeLabelRepository
        self.photoStorage = photoStorage

        var catalogIdForSave: UUID?

        if let item = existingItem {
            name = item.name
            quantity = String(item.quantity)
            selectedUnit = item.unit
            selectedStorageLocation = item.storageLocation
            category = Self.predefinedCategories.contains(item.category) ? item.category : "Custom"
            customCategory = Self.predefinedCategories.contains(item.category) ? "" : item.category
            if let expiry = item.expiryDate {
                hasExpiry = true
                expiryDate = expiry
            }
        } else if let catalogItem {
            name = catalogItem.name
            selectedUnit = catalogItem.defaultUnit
            let cat = catalogItem.defaultCategory
            if Self.predefinedCategories.contains(cat) {
                category = cat
            } else {
                category = "Custom"
                customCategory = cat
            }
            catalogIdForSave = catalogItem.catalogItemId
        } else if let prefillFrom {
            name = prefillFrom.name
            quantity = String(prefillFrom.quantity)
            selectedUnit = prefillFrom.unit
            selectedStorageLocation = prefillFrom.storageLocation
            if Self.predefinedCategories.contains(prefillFrom.category) {
                category = prefillFrom.category
            } else {
                category = "Custom"
                customCategory = prefillFrom.category
            }
        } else {
            if let n = barcodePrefillName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                name = n
            }
            if let cat = barcodePrefillCategory {
                if Self.predefinedCategories.contains(cat) {
                    category = cat
                } else {
                    category = "Custom"
                    customCategory = cat
                }
            }
        }

        self.catalogItemIdForBarcodeSave = catalogIdForSave

        // For new items, default expiry to ON — most pantry foods have expiry dates
        if existingItem == nil && !hasExpiry {
            hasExpiry = true
            expiryDate = Date.now.addingTimeInterval(7 * 24 * 60 * 60)
        }

        if quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quantity = "1"
        }

        if let hint = barcodeNotFoundHint {
            photoRecognitionHint = hint
            photoRecognitionHintIsError = false
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

    func applyPhotoRecognitionResult(_ result: ProductRecognitionResult) {
        lastRecognitionConfidence = result.confidence
        lastRecognitionIsLikelyFood = result.isLikelyFood
        name = result.suggestedName

        // High-confidence food: auto-apply name, suppress suggestion chips
        if result.confidence >= 0.80, result.isLikelyFood {
            photoRecognitionSuggestions = []
        } else {
            photoRecognitionSuggestions = result.suggestions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if Self.predefinedCategories.contains(result.category) {
            category = result.category
            customCategory = ""
        } else {
            category = "Other"
            customCategory = ""
        }
        photoRecognitionHintIsError = false
        if !result.isLikelyFood {
            photoRecognitionHint = String(localized: "This doesn't look like a food item — double-check before saving.")
        } else if result.confidence < Self.lowConfidenceThreshold {
            photoRecognitionHint = String(localized: "Low-confidence match — review name and category before saving.")
        } else {
            photoRecognitionHint = String(localized: "Filled from photo — review name and category, then save.")
        }
    }

    func applyPhotoRecognitionSuggestion(_ suggestedName: String) {
        let trimmed = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = trimmed
        photoRecognitionHintIsError = false
        photoRecognitionHint = String(localized: "Updated from suggestion — review and save.")
    }

    func recognizeFromPhoto(image: UIImage) async {
        isRecognizingFromPhoto = true
        recognizedPhotoPreview = image
        lastRecognitionConfidence = nil
        lastRecognitionIsLikelyFood = true
        photoRecognitionSuggestions = []
        photoRecognitionHint = nil
        photoRecognitionHintIsError = false
        defer { isRecognizingFromPhoto = false }
        do {
            let result = try await ProductRecognitionService.recognize(from: image)
            applyPhotoRecognitionResult(result)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            photoRecognitionHintIsError = true
            photoRecognitionHint = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Resets the form fields for "Save & add another" flow.
    func resetForAnotherItem() {
        name = ""
        quantity = "1"
        selectedUnit = .pcs
        hasExpiry = false
        expiryDate = Date.now.addingTimeInterval(7 * 24 * 60 * 60)
        category = "Other"
        customCategory = ""
        selectedStorageLocation = .shelf
        validationErrors = []
        errorMessage = nil
        recognizedPhotoPreview = nil
        photoRecognitionHint = nil
        photoRecognitionHintIsError = false
        photoRecognitionSuggestions = []
        lastRecognitionConfidence = nil
        lastRecognitionIsLikelyFood = true
        lastSavedItemId = nil
        lastSavedItem = nil
    }

    private func persistBarcodeLabelIfNeeded(trimmedName: String) async {
        guard !isEditing,
              let digits = scannedBarcodeDigits,
              !digits.isEmpty,
              let repo = barcodeLabelRepository
        else { return }

        do {
            try await repo.upsertLabel(
                householdId: householdId,
                barcode: digits,
                displayName: trimmedName,
                category: resolvedCategory,
                catalogItemId: catalogItemIdForBarcodeSave
            )
        } catch {
            Self.logger.warning("Barcode label upsert failed: \(error.localizedDescription)")
        }
    }

    private func uploadRecognizedPhotoIfNeeded(itemId: UUID) async throws -> String? {
        guard let image = recognizedPhotoPreview else { return nil }
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw ProductRecognitionError.invalidImage
        }
        return try await photoStorage.uploadPhoto(
            data: data,
            householdId: householdId,
            itemId: itemId
        )
    }

    func delete() async -> Bool {
        guard isEditing, let item = existingItem else { return false }

        isLoading = true
        errorMessage = nil

        do {
            try await withRetry { [repository] in
                try await repository.delete(itemId: item.itemId)
            }

            ToastManager.shared.show("\(item.name) deleted", style: .success)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isLoading = false
            return true
        } catch {
            errorMessage = ErrorHandler.userMessage(for: error, action: "delete item")
            ToastManager.shared.show(errorMessage!, style: .error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isLoading = false
            return false
        }
    }

    func save() async -> Bool {
        // Check pantry item limit before creating new items
        if !isEditing, let gate = featureGateService {
            let allowed = await gate.checkLimit(.pantryItems, householdId: householdId)
            if !allowed { return false }
        }

        guard validate() else { return false }

        isLoading = true
        errorMessage = nil

        let parsedQuantity = Double(quantity) ?? 1

        do {
            if isEditing, var item = existingItem {
                guard userRole == .admin || (item.approvalStatus == .pending && item.createdBy == userId) else {
                    errorMessage = "You can't edit this item."
                    isLoading = false
                    return false
                }
                item.name = name.trimmingCharacters(in: .whitespaces)
                item.quantity = parsedQuantity
                item.unit = selectedUnit
                item.category = resolvedCategory
                item.storageLocation = selectedStorageLocation
                item.expiryDate = hasExpiry ? expiryDate : nil
                item.updatedAt = .now
                if let photoPath = try await uploadRecognizedPhotoIfNeeded(itemId: item.itemId) {
                    item.photoPath = photoPath
                }
                let capturedItem = item
                _ = try await withRetry { [repository] in try await repository.update(capturedItem) }
            } else {
                // Always create new pantry item (no auto-merging)
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let itemId = UUID()
                let item = PantryItem(
                    itemId: itemId,
                    householdId: householdId,
                    name: trimmedName,
                    quantity: parsedQuantity,
                    unit: selectedUnit,
                    category: resolvedCategory,
                    storageLocation: selectedStorageLocation,
                    expiryDate: hasExpiry ? expiryDate : nil,
                    costPerUnitMinor: nil,
                    lowStockThreshold: 1,
                    createdBy: userId,
                    createdAt: .now,
                    updatedAt: .now,
                    archived: false,
                    lastQuantityUpdateDate: .now,
                    expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: resolvedCategory),
                    photoPath: try await uploadRecognizedPhotoIfNeeded(itemId: itemId),
                    approvalStatus: insertsAsApproved ? .approved : .pending
                )
                Self.logger.debug("Inserting pantry item: created_by=\(self.userId), household_id=\(self.householdId)")
                _ = try await withRetry { [repository] in try await repository.add(item) }
                lastSavedItemId = itemId
                lastSavedItem = item
                onSaveSuccess?(item)
                await persistBarcodeLabelIfNeeded(trimmedName: trimmedName)
            }

            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            if !suppressToast {
                let toastText: String
                if isEditing {
                    toastText = "\(name) updated"
                } else if insertsAsApproved {
                    toastText = "\(name) added to pantry"
                } else {
                    toastText = "\(name) submitted for admin approval"
                }
                ToastManager.shared.show(toastText, style: .success)
            }

            isLoading = false
            return true
        } catch {
            Self.logger.error("Pantry item save failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "save item"),
                style: .error
            )
            isLoading = false
            return false
        }
    }
}
