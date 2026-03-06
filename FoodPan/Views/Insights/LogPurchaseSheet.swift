import SwiftUI

struct LogPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var financeVM: FinanceViewModel
    var onDismiss: (() -> Void)?

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var storeName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount")
                            .font(AppFont.body)
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppFont.body)
                            .frame(maxWidth: 120)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .font(AppFont.body)

                    TextField("Store (optional)", text: $storeName)
                        .font(AppFont.body)
                        .autocapitalization(.words)
                } header: {
                    Text("Purchase Details")
                } footer: {
                    Text("Log a purchase you made without using the shopping list. The amount will count toward your budget.")
                }
            }
            .navigationTitle("Log Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss?()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let amount = Double(amountText.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            ToastManager.shared.show("Enter a valid amount", style: .error)
            return
        }
        isSaving = true

        do {
            let amountMinor = Int(amount * 100)
            let store = storeName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : storeName.trimmingCharacters(in: .whitespaces)
            try await financeVM.logManualPurchase(amountMinor: amountMinor, date: date, storeName: store)
            dismiss()
            onDismiss?()
        } catch {
            ToastManager.shared.show("Failed to log purchase", style: .error)
        }

        isSaving = false
    }
}
