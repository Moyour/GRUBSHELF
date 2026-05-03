import SwiftUI

struct ReceiptConfirmationSheet: View {
    @State private var viewModel: ReceiptConfirmationViewModel
    @Environment(\.dismiss) private var dismiss

    let financeVM: FinanceViewModel
    let onDismiss: () -> Void
    private let currencyCode: String

    init(
        parsedReceipt: ParsedReceipt,
        financeVM: FinanceViewModel,
        currencyCode: String = "GBP",
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: ReceiptConfirmationViewModel(parsedReceipt: parsedReceipt))
        self.financeVM = financeVM
        self.onDismiss = onDismiss
        self.currencyCode = currencyCode
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                        .font(BrandFont.regular(17))

                    TextField("Store (optional)", text: $viewModel.storeName)
                        .textInputAutocapitalization(.words)

                    HStack {
                        Text("Total")
                            .font(BrandFont.regular(17))
                        Spacer()
                        TextField("0.00", text: $viewModel.manualTotalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(BrandFont.semiBold(17))
                    }
                } header: {
                    Text("Receipt details")
                } footer: {
                    Text(
                        "We’ll log the total above against your budget—tweak it if the scan was off. Lines below are just for you to sanity-check."
                    )
                }

                Section {
                    ForEach(viewModel.items) { item in
                        HStack {
                            TextField("Item", text: Binding(
                                get: { item.name },
                                set: { viewModel.updateItemName(id: item.id, name: $0) }
                            ))
                            .font(BrandFont.regular(17))
                            if let price = item.priceMinor, price > 0 {
                                Text(price.currencyFormatted(currencyCode: currencyCode))
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Items (from receipt)")
                } footer: {
                    Text(
                        "No prices on the lines? Type the receipt total up top."
                    )
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Confirm receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { @MainActor in
                            await viewModel.logPurchase(using: financeVM)
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Log purchase")
                                .font(BrandFont.semiBold(17))
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onAppear {
                viewModel.onSuccess = { [dismiss, onDismiss] in
                    dismiss()
                    onDismiss()
                }
            }
        }
    }
}
