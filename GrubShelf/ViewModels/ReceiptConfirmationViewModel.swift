import Foundation
import Observation

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

    var onSuccess: (() -> Void)?

    init(parsedReceipt: ParsedReceipt) {
        self.items = parsedReceipt.items
        self.totalMinor = parsedReceipt.totalMinor
        self.storeName = parsedReceipt.storeName ?? ""
        self.date = parsedReceipt.date ?? Date()
        if let t = parsedReceipt.totalMinor, t > 0 {
            self.manualTotalText = Self.formatDecimal(fromMinor: t)
        } else {
            let sum = parsedReceipt.items.compactMap(\.priceMinor).filter { $0 > 0 }.reduce(0, +)
            self.manualTotalText = sum > 0 ? Self.formatDecimal(fromMinor: sum) : ""
        }
    }

    private static func formatDecimal(fromMinor minor: Int) -> String {
        String(format: "%.2f", Double(minor) / 100.0)
    }

    func updateItemName(id: UUID, name: String) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].name = name
        }
    }

    /// Amount for budget logging: manual entry if set, else receipt total, else sum of line prices.
    private func resolvedAmountMinor() -> Int? {
        let trimmed = manualTotalText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let parsed = Self.parseAmountMinor(trimmed) {
            return parsed
        }
        if let t = totalMinor, t > 0 { return t }
        let sum = items.compactMap(\.priceMinor).filter { $0 > 0 }.reduce(0, +)
        return sum > 0 ? sum : nil
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
            onSuccess?()
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.show("Couldn’t log that—try again?", style: .error)
        }
    }
}
