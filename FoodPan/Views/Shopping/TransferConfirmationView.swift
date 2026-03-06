import SwiftUI

struct TransferConfirmationView: View {
    @State var viewModel: TransferViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Trip Cost Section (required)
                    VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                        HStack(spacing: 10) {
                            Image(systemName: "creditcard.fill")
                                .font(.title2)
                                .foregroundStyle(Color.primaryGreen)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Trip Total")
                                        .font(AppFont.sectionTitle)
                                        .foregroundStyle(Color.primaryText)
                                    Text("*")
                                        .font(AppFont.sectionTitle)
                                        .foregroundStyle(Color.errorRed)
                                }
                                Text("Required — enter the total amount spent")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }

                        HStack(spacing: 8) {
                            Text("$")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primaryGreen)

                            TextField("0.00", text: $viewModel.tripTotalCost)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.primaryText)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

                        if !viewModel.tripTotalCost.isEmpty && !viewModel.canTransfer {
                            Text("Enter a valid amount greater than 0")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.errorRed)
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(Color.primaryGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                            .strokeBorder(Color.primaryGreen.opacity(0.3), lineWidth: 1)
                    )

                    ForEach($viewModel.transferItems) { $item in
                        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                            Text(item.shoppingItem.name)
                                .font(AppFont.button)
                                .foregroundStyle(Color.primaryText)

                            HStack {
                                Text("Qty")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                                TextField("Quantity", text: $item.quantity)
                                    .keyboardType(.decimalPad)
                                    .font(AppFont.body)
                            }

                            Toggle("Has expiry", isOn: $item.hasExpiry)
                                .font(AppFont.body)

                            if item.hasExpiry {
                                DatePicker("Expiry", selection: $item.expiryDate, displayedComponents: .date)
                                    .font(AppFont.body)
                            }

                            HStack {
                                Text("Cost")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                                TextField("Total cost", text: $item.totalCost)
                                    .keyboardType(.decimalPad)
                                    .font(AppFont.body)
                            }

                            HStack {
                                Text("Store")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                                TextField("Store name", text: $item.storeName)
                                    .font(AppFont.body)
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                        .cardShadow()
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(Color.appBackground)
            .navigationTitle("Transfer to Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.executeTransfer() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Transfer")
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canTransfer)
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
