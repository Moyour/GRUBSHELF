import SwiftUI

struct TransferConfirmationView: View {
    @State var viewModel: TransferViewModel
    var currencyCode: String = "GBP"
    var embedded: Bool = false
    var didComplete: Binding<Bool>?
    @Environment(\.dismiss) private var dismiss

    private var currencySymbol: String {
        Locale.currencySymbol(for: currencyCode)
    }

    var body: some View {
        if embedded {
            transferContent
        } else {
            NavigationStack {
                transferContent
            }
        }
    }

    @ViewBuilder
    private var transferContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    HStack(spacing: AppSpacing.mediumSpacing) {
                        Image(systemName: "creditcard.fill")
                            .font(BrandSymbolFont.symbol(22))
                            .foregroundStyle(.gsBrandPrimary)

                        VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                            HStack(spacing: AppSpacing.compactGap) {
                                Text("Trip total")
                                    .font(BrandFont.semiBold(18))
                                    .foregroundStyle(.gsTextPrimary)
                                Text("*")
                                    .font(BrandFont.semiBold(18))
                                    .foregroundStyle(.gsDanger)
                            }
                            Text("Required — enter the total amount spent")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                        }
                    }

                    HStack(spacing: AppSpacing.smallSpacing) {
                        Text(currencySymbol)
                            .font(BrandFont.bold(26))
                            .foregroundStyle(.gsBrandPrimary)

                        TextField("0.00", text: $viewModel.tripTotalCost)
                            .keyboardType(.decimalPad)
                            .font(BrandFont.semiBold(26))
                            .foregroundStyle(.gsTextPrimary)
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(.gsSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

                    if !viewModel.tripTotalCost.isEmpty && !viewModel.canTransfer {
                        Text("Enter a valid amount greater than 0")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(.gsBrandPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .strokeBorder(.gsBrandPrimary.opacity(0.3), lineWidth: 1)
                )

                ForEach($viewModel.transferItems) { $item in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                            HStack {
                                Text("Qty")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                TextField("Quantity", text: $item.quantity)
                                    .keyboardType(.decimalPad)
                                    .font(BrandFont.regular(17))
                            }

                            Toggle("Has expiry", isOn: $item.hasExpiry)
                                .font(BrandFont.regular(17))

                            if item.hasExpiry {
                                DatePicker("Expiry", selection: $item.expiryDate, displayedComponents: .date)
                                    .font(BrandFont.regular(17))
                            }

                            HStack {
                                Text("Cost")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                HStack(spacing: AppSpacing.compactGap) {
                                    Text(currencySymbol)
                                        .font(BrandFont.regular(17))
                                        .foregroundStyle(.gsTextSecondary)
                                    TextField("Optional", text: $item.totalCost)
                                        .keyboardType(.decimalPad)
                                        .font(BrandFont.regular(17))
                                }
                            }

                            HStack {
                                Text("Store")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                TextField("Optional", text: $item.storeName)
                                    .font(BrandFont.regular(17))
                            }
                        }
                    } label: {
                        HStack(spacing: AppSpacing.smallSpacing) {
                            Text(item.shoppingItem.name)
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextPrimary)
                            Text("×\(item.quantity)")
                                .font(BrandFont.mono(13))
                                .foregroundStyle(.gsTextSecondary)
                                .padding(.horizontal, AppSpacing.denseSpacing)
                                .padding(.vertical, AppSpacing.microGap)
                                .background(.gsBackground)
                                .clipShape(Capsule())
                        }
                    }
                    .tint(.gsTextSecondary)
                    .padding(AppSpacing.cardPadding)
                    .dashboardCardSurface()
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(.gsBackground)
        .navigationTitle("Transfer to pantry")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                if !viewModel.canTransfer {
                    Text("Enter a trip total above (greater than 0) to move items to your pantry.")
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    Task {
                        if await viewModel.executeTransfer() {
                            if let didComplete {
                                didComplete.wrappedValue = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.gsTextOnBrand)
                        } else {
                            Text("Transfer to pantry")
                                .font(BrandFont.semiBold(17))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.gsTextOnBrand)
                .background(viewModel.canTransfer && !viewModel.isLoading ? Color.gsBrandPrimary : Color.gsBrandPrimary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
                .disabled(viewModel.isLoading || !viewModel.canTransfer)
            }
            .padding(AppSpacing.screenPadding)
            .frame(maxWidth: .infinity)
            .background(.gsBackground)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(embedded ? "Back" : "Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
