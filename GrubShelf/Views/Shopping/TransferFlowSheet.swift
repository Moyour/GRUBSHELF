import SwiftUI
import UIKit

/// Single-sheet shop → pantry transfer: optional pantry audit, required trip total, item details, one confirm.
struct TransferFlowSheet: View {
    let householdId: UUID
    let userId: UUID
    let listId: UUID?
    var currencyCode: String = "GBP"
    var onTransferComplete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var auditViewModel: ShoppingAuditViewModel
    @State private var transferViewModel: TransferViewModel

    init(
        transferableItems: [ShoppingItem],
        pantryItems: [PantryItem],
        householdId: UUID,
        userId: UUID,
        listId: UUID?,
        currencyCode: String = "GBP",
        onTransferComplete: (() async -> Void)? = nil
    ) {
        self.householdId = householdId
        self.userId = userId
        self.listId = listId
        self.currencyCode = currencyCode
        self.onTransferComplete = onTransferComplete

        let auditVM = ShoppingAuditViewModel(
            transferableItems: transferableItems,
            pantryItems: pantryItems
        )
        _auditViewModel = State(initialValue: auditVM)
        _transferViewModel = State(initialValue: TransferViewModel(
            completedItems: transferableItems,
            pantryRepository: SupabasePantryRepository(),
            transactionRepository: SupabaseTransactionRepository(),
            shoppingRepository: SupabaseShoppingRepository(),
            householdId: householdId,
            userId: userId,
            listId: listId,
            auditEntries: auditVM.entries
        ))
    }

    private var currencySymbol: String {
        Locale.currencySymbol(for: currencyCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if auditViewModel.hasMatches {
                        TransferAuditContent(auditViewModel: auditViewModel)
                    }

                    tripTotalCard

                    ForEach($transferViewModel.transferItems) { $item in
                        transferItemCard($item)
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(.gsBackground)
            .navigationTitle("Transfer to pantry")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                transferFooter
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(BrandFont.semiBold(15))
                }
            }
            .task {
                await transferViewModel.loadSuggestedTripTotal()
            }
            .alert("Error", isPresented: .init(
                get: { transferViewModel.errorMessage != nil },
                set: { if !$0 { transferViewModel.errorMessage = nil } }
            )) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text(transferViewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Trip total

    private var tripTotalCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(spacing: AppSpacing.mediumSpacing) {
                Image(systemName: "creditcard.fill")
                    .font(BrandSymbolFont.symbol(22))
                    .foregroundStyle(.gsBrandPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text("Trip total")
                        .font(BrandFont.semiBold(18))
                        .foregroundStyle(.gsTextPrimary)
                    Text("Optional — used for your budget and Expenses. Leave blank to skip.")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                    if transferViewModel.didPrefillTripTotal {
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

                TextField("0.00", text: $transferViewModel.tripTotalCost)
                    .keyboardType(.decimalPad)
                    .font(BrandFont.semiBold(26))
                    .foregroundStyle(.gsTextPrimary)
                    .onChange(of: transferViewModel.tripTotalCost) { _, _ in
                        transferViewModel.didPrefillTripTotal = false
                    }
            }
            .padding(AppSpacing.cardPadding)
            .background(.gsSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))

            if !transferViewModel.tripTotalCost.isEmpty && !transferViewModel.canTransfer {
                Text("Enter a valid amount or clear the field to skip")
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

    private func transferItemCard(_ item: Binding<TransferViewModel.TransferItem>) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                HStack {
                    Text("Qty")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                    TextField("Quantity", text: item.quantity)
                        .keyboardType(.decimalPad)
                        .font(BrandFont.regular(17))
                }

                Toggle("Has expiry", isOn: item.hasExpiry)
                    .font(BrandFont.regular(17))

                if item.wrappedValue.hasExpiry {
                    DatePicker("Expiry", selection: item.expiryDate, displayedComponents: .date)
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
                        TextField("Optional", text: item.totalCost)
                            .keyboardType(.decimalPad)
                            .font(BrandFont.regular(17))
                    }
                }

                HStack {
                    Text("Store")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                    TextField("Optional", text: item.storeName)
                        .font(BrandFont.regular(17))
                }
            }
        } label: {
            HStack(spacing: AppSpacing.smallSpacing) {
                Text(item.wrappedValue.shoppingItem.name)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                Text("×\(item.wrappedValue.quantity)")
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

    private var transferFooter: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            if !transferViewModel.tripTotalCost.isEmpty && !transferViewModel.canTransfer {
                Text("Enter a valid amount or clear the field to skip.")
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task {
                    if await transferViewModel.executeTransfer() {
                        await onTransferComplete?()
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if transferViewModel.isLoading {
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
            .background(
                transferViewModel.canTransfer && !transferViewModel.isLoading
                    ? Color.gsBrandPrimary
                    : Color.gsBrandPrimary.opacity(0.35)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .disabled(transferViewModel.isLoading || !transferViewModel.canTransfer)
        }
        .padding(AppSpacing.screenPadding)
        .frame(maxWidth: .infinity)
        .background(.gsBackground)
    }
}
