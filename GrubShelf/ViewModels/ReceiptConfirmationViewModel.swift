import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ReceiptConfirmationViewModel {
    var items: [ParsedReceiptItem]
    var totalMinor: Int?
    /// User-editable major units (e.g. "12.99"); pre-filled from OCR when possible.
    var manualTotalText: String
    var storeName: String
    var date: Date
    var isSaving = false
    var errorMessage: String?
    /// True when `manualTotalText` was prefilled from a previous logged shop.
    var didPrefillTotal = false

    // MARK: - Pantry auto-add

    /// Master toggle: when true, selected items are also added to the pantry.
    var addToPantryEnabled = true
    private let pantryRepository: PantryRepository?
    private let householdId: UUID?
    private let userId: UUID?
    private let userRole: UserRole

    /// True when all dependencies for pantry auto-add are present.
    var canAddToPantry: Bool {
        pantryRepository != nil && householdId != nil && userId != nil
    }

    /// Number of items currently selected for pantry add.
    var pantrySelectionCount: Int {
        items.filter(\.addToPantry).count
    }

    /// True when per-item pantry checkboxes should be shown.
    var showPantryCheckboxes: Bool {
        canAddToPantry && addToPantryEnabled
    }

    var onSuccess: (() -> Void)?

    var canLogPurchase: Bool {
        resolvedAmountMinor() != nil
    }

    /// Empty state for manual entry before or without a receipt scan.
    init(
        pantryRepository: PantryRepository? = nil,
        householdId: UUID? = nil,
        userId: UUID? = nil,
        userRole: UserRole = .member
    ) {
        self.items = []
        self.totalMinor = nil
        self.manualTotalText = ""
        self.storeName = ""
        self.date = .now
        self.pantryRepository = pantryRepository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
    }

    init(
        parsedReceipt: ParsedReceipt,
        pantryRepository: PantryRepository? = nil,
        householdId: UUID? = nil,
        userId: UUID? = nil,
        userRole: UserRole = .member
    ) {
        self.items = parsedReceipt.items
        self.totalMinor = parsedReceipt.totalMinor
        self.storeName = parsedReceipt.storeName ?? ""
        self.date = parsedReceipt.date ?? Date()
        self.pantryRepository = pantryRepository
        self.householdId = householdId
        self.userId = userId
        self.userRole = userRole
        if let t = parsedReceipt.totalMinor, t > 0 {
            self.manualTotalText = Self.formatDecimal(fromMinor: t)
        } else {
            let sum = parsedReceipt.items.compactMap(\.priceMinor).filter { $0 > 0 }.reduce(0, +)
            self.manualTotalText = sum > 0 ? Self.formatDecimal(fromMinor: sum) : ""
        }
    }

    /// Prefills total from the most recent logged shop when the field is still empty.
    func loadSuggestedTotalIfNeeded(
        householdId: UUID,
        shoppingTripRepository: ShoppingTripRepository = SupabaseShoppingTripRepository()
    ) async {
        guard manualTotalText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -30, to: .now) else { return }
        guard let trips = try? await shoppingTripRepository.fetchByDateRange(
            householdId: householdId,
            start: start,
            end: .now
        ) else { return }

        guard let last = trips.first(where: { $0.costLogged && ($0.totalCostMinor ?? 0) > 0 }),
              let minor = last.totalCostMinor else {
            return
        }

        manualTotalText = TransferViewModel.formatMajorAmount(fromMinor: minor)
        didPrefillTotal = true
    }

    func updateItemName(id: UUID, name: String) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].name = name
        }
    }

    /// Toggles the pantry selection for a single item.
    func togglePantrySelection(id: UUID) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].addToPantry.toggle()
        }
    }

    /// Amount for budget logging: manual entry if set, else receipt total, else sum of line prices.
    func resolvedAmountMinor() -> Int? {
        let trimmed = manualTotalText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let parsed = Self.parseAmountMinor(trimmed) {
            return parsed
        }
        if let t = totalMinor, t > 0 { return t }
        let sum = items.compactMap(\.priceMinor).filter { $0 > 0 }.reduce(0, +)
        return sum > 0 ? sum : nil
    }

    private static func formatDecimal(fromMinor minor: Int) -> String {
        TransferViewModel.formatMajorAmount(fromMinor: minor)
    }

    private static func parseAmountMinor(_ text: String) -> Int? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard let value = Double(normalized), value > 0 else { return nil }
        return Int((value * 100).rounded())
    }

    func logPurchase(using financeVM: FinanceViewModel) async {
        guard let amount = resolvedAmountMinor(), amount > 0 else {
            errorMessage =
                "Add a total above (or line prices) so we know what to log."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let trimmedStore = storeName.trimmingCharacters(in: .whitespaces)
            try await financeVM.logManualPurchase(
                amountMinor: amount,
                date: date,
                storeName: trimmedStore.isEmpty ? nil : trimmedStore
            )

            // Add selected items to pantry
            var pantryAddCount = 0
            if addToPantryEnabled, canAddToPantry,
               let repo = pantryRepository,
               let hId = householdId,
               let uId = userId {
                let selectedItems = items.filter(\.addToPantry)
                for item in selectedItems {
                    let trimmedName = item.name.trimmingCharacters(in: .whitespaces)
                    guard !trimmedName.isEmpty else { continue }
                    let category = "Other"
                    let pantryItem = PantryItem(
                        itemId: UUID(),
                        householdId: hId,
                        name: trimmedName,
                        quantity: item.quantity ?? 1,
                        unit: .pcs,
                        category: category,
                        storageLocation: .shelf,
                        expiryDate: Calendar.current.date(
                            byAdding: .day,
                            value: PantryItem.defaultUsageCycleDays(for: category),
                            to: date
                        ),
                        costPerUnitMinor: item.priceMinor,
                        lowStockThreshold: 1,
                        createdBy: uId,
                        createdAt: .now,
                        updatedAt: .now,
                        archived: false,
                        lastQuantityUpdateDate: .now,
                        expectedUsageCycleDays: PantryItem.defaultUsageCycleDays(for: category),
                        approvalStatus: userRole == .admin ? .approved : .pending
                    )
                    do {
                        _ = try await repo.add(pantryItem)
                        pantryAddCount += 1
                    } catch {
                        // Best-effort: continue with remaining items
                    }
                }
            }

            let toastText: String
            if pantryAddCount > 0 {
                toastText = "Purchase logged \u{00B7} \(pantryAddCount) item\(pantryAddCount == 1 ? "" : "s") added to pantry"
            } else {
                toastText = "Purchase logged"
            }
            ToastManager.shared.show(toastText, style: .success)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSuccess?()
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show("Couldn't log that\u{2014}try again?", style: .error)
        }
    }
}
