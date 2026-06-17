import SwiftUI

/// Confirm UI embedded in [`ReceiptFlowSheet`] after OCR (date, store, total, line items).
struct ReceiptConfirmContent: View {
    @Bindable var viewModel: ReceiptConfirmationViewModel
    let currencyCode: String
    var onRescan: () -> Void

    private var currencySymbol: String {
        Locale.currencySymbol(for: currencyCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            HStack {
                Text("Receipt details")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Spacer()
                Button("Rescan", action: onRescan)
                    .font(BrandFont.medium(15))
                    .foregroundStyle(.gsBrandPrimary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    .font(BrandFont.regular(17))

                TextField("Store (optional)", text: $viewModel.storeName)
                    .font(BrandFont.regular(17))
                    .textInputAutocapitalization(.words)
            }
            .padding(AppSpacing.cardPadding)
            .dashboardCardSurface()

            totalCard

            if !viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.smallSpacing) {
                    HStack {
                        Text("Items")
                            .font(BrandFont.semiBold(17))
                            .foregroundStyle(.gsTextPrimary)
                        Spacer()
                        if viewModel.canAddToPantry {
                            Button {
                                viewModel.addToPantryEnabled.toggle()
                            } label: {
                                HStack(spacing: AppSpacing.compactGap) {
                                    Image(systemName: viewModel.addToPantryEnabled ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(viewModel.addToPantryEnabled ? .gsBrandPrimary : .gsTextSecondary)
                                    Text("Add to pantry")
                                        .font(BrandFont.medium(14))
                                        .foregroundStyle(.gsTextPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.showPantryCheckboxes {
                        Text("Tick the items you want in your pantry.")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                    } else {
                        Text("These lines help you sanity-check the scan.")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                    }

                    ForEach(viewModel.items) { item in
                        HStack {
                            if viewModel.showPantryCheckboxes {
                                Button {
                                    viewModel.togglePantrySelection(id: item.id)
                                } label: {
                                    Image(systemName: item.addToPantry ? "checkmark.circle.fill" : "circle")
                                        .font(BrandSymbolFont.symbol(20))
                                        .foregroundStyle(item.addToPantry ? .gsBrandPrimary : .gsTextSecondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }

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
                        .padding(AppSpacing.cardPadding)
                        .dashboardCardSurface()
                    }

                    if viewModel.showPantryCheckboxes {
                        Text("\(viewModel.pantrySelectionCount) of \(viewModel.items.count) item\(viewModel.items.count == 1 ? "" : "s") will be added to pantry")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsDanger)
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(spacing: AppSpacing.mediumSpacing) {
                Image(systemName: "creditcard.fill")
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(.gsBrandPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    HStack(spacing: AppSpacing.compactGap) {
                        Text("Purchase total")
                            .font(BrandFont.semiBold(18))
                            .foregroundStyle(.gsTextPrimary)
                        Text("*")
                            .font(BrandFont.semiBold(18))
                            .foregroundStyle(.gsDanger)
                    }
                    Text("Used for your budget and Expenses — adjust if the scan was off.")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                    if viewModel.didPrefillTotal {
                        Text("Prefilled from your last shop")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsBrandPrimary.opacity(0.9))
                    }
                }
            }

            HStack(spacing: AppSpacing.smallSpacing) {
                Text(currencySymbol)
                    .font(BrandFont.bold(26))
                    .foregroundStyle(.gsBrandPrimary)

                TextField("0.00", text: $viewModel.manualTotalText)
                    .keyboardType(.decimalPad)
                    .font(BrandFont.semiBold(26))
                    .foregroundStyle(.gsTextPrimary)
                    .onChange(of: viewModel.manualTotalText) { _, _ in
                        viewModel.didPrefillTotal = false
                    }
            }
            .padding(AppSpacing.cardPadding)
            .background(.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

            if !viewModel.manualTotalText.isEmpty && !viewModel.canLogPurchase {
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
    }
}
