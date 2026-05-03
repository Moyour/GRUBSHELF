import SwiftUI

struct LogPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var financeVM: FinanceViewModel
    var onDismiss: (() -> Void)?

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var storeName = ""
    @State private var isSaving = false
    @State private var showReceiptScan = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showReceiptScan = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.viewfinder")
                            Text("Scan receipt")
                        }
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsBrandPrimary)
                    }
                } header: {
                    Text("Quick add")
                }

                Section {
                    HStack {
                        Text("Amount")
                            .font(BrandFont.regular(17))
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(BrandFont.regular(17))
                            .frame(maxWidth: 120)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .font(BrandFont.regular(17))

                    TextField("Store (optional)", text: $storeName)
                        .font(BrandFont.regular(17))
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Purchase details")
                } footer: {
                    Text("Bought something off-list? Log it here so your budget stays honest.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Log purchase")
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
            .sheet(isPresented: $showReceiptScan, onDismiss: onDismiss) {
                ReceiptScanSheet(
                    financeVM: financeVM,
                    onDismiss: {
                        dismiss()
                        onDismiss?()
                    }
                )
            }
        }
    }

    private func save() async {
        guard let amount = Double(amountText.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            ToastManager.shared.show("Pick an amount above zero", style: .error)
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
            ToastManager.shared.show("Couldn’t log that—try again?", style: .error)
        }

        isSaving = false
    }
}
