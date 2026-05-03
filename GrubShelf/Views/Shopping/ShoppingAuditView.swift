import SwiftUI

struct ShoppingAuditView: View {
    @State var auditViewModel: ShoppingAuditViewModel
    let transferableItems: [ShoppingItem]
    let householdId: UUID
    let userId: UUID
    let listId: UUID?
    var currencyCode: String = "GBP"

    @State private var showTransfer = false
    @State private var transferDidComplete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    headerCard

                    if !auditSummaryText.isEmpty {
                        Text(auditSummaryText)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach($auditViewModel.entries) { $entry in
                        if entry.matchedPantryItem != nil {
                            matchedRow(entry: $entry)
                        }
                    }

                    if !auditViewModel.orphanedItems.isEmpty {
                        orphanedSection
                    }

                    if !auditViewModel.unmatchedEntries.isEmpty {
                        newItemsSection
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(.gsBackground)
            .navigationTitle("Pantry audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") { showTransfer = true }
                        .font(BrandFont.semiBold(17))
                }
            }
            .navigationDestination(isPresented: $showTransfer) {
                TransferConfirmationView(
                    viewModel: TransferViewModel(
                        completedItems: transferableItems,
                        pantryRepository: SupabasePantryRepository(),
                        transactionRepository: SupabaseTransactionRepository(),
                        shoppingRepository: SupabaseShoppingRepository(),
                        householdId: householdId,
                        userId: userId,
                        listId: listId,
                        auditEntries: auditViewModel.entries
                    ),
                    currencyCode: currencyCode,
                    embedded: true,
                    didComplete: $transferDidComplete
                )
            }
            .onChange(of: transferDidComplete) {
                if transferDidComplete { dismiss() }
            }
        }
    }

    // MARK: - Summary

    private var auditSummaryText: String {
        var parts: [String] = []
        let matched = auditViewModel.matchedEntries.count
        let new = auditViewModel.unmatchedEntries.count
        let orphaned = auditViewModel.orphanedItems.count
        if matched > 0 { parts.append("\(matched) matched") }
        if new > 0 { parts.append("\(new) new") }
        if orphaned > 0 { parts.append("\(orphaned) orphaned") }
        guard !parts.isEmpty else { return "" }
        return "Reviewing \(parts.joined(separator: ", ")) items"
    }

    // MARK: - Subviews

    private var headerCard: some View {
        HStack(spacing: AppSpacing.mediumSpacing) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(BrandSymbolFont.symbol(22))
                .foregroundStyle(.gsBrandPrimary)
            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text("Quick pantry check")
                    .font(BrandFont.semiBold(18))
                    .foregroundStyle(.gsTextPrimary)
                Text("You're re-buying items already in your pantry — what happened to them?")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(.gsBrandPrimary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .strokeBorder(.gsBrandPrimary.opacity(0.3), lineWidth: 1)
        )
    }

    private func matchedRow(entry: Binding<AuditEntry>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                    Text(entry.wrappedValue.shoppingItem.name)
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(.gsTextPrimary)
                    if let pantry = entry.wrappedValue.matchedPantryItem {
                        Text("In pantry: \(pantry.quantity.formatted()) \(pantry.unit.abbreviation)")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
                Spacer()
            }

            Picker("Status", selection: entry.resolution) {
                ForEach(AuditResolution.allCases, id: \.self) { res in
                    Text(res.label).tag(res)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(AppSpacing.cardPadding)
        .dashboardCardSurface()
    }

    private var orphanedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(spacing: AppSpacing.smallSpacing) {
                Image(systemName: "clock.badge.questionmark")
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(.gsWarning)
                Text("Still have these?")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)

            ForEach(auditViewModel.orphanedItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                        Text(item.name)
                            .font(BrandFont.regular(17))
                            .foregroundStyle(.gsTextPrimary)
                        Text("Added \(item.daysSinceLastUpdate) days ago · \(item.quantity.formatted()) \(item.unit.abbreviation)")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                    }
                    Spacer()
                    Text(item.category)
                        .font(BrandFont.regular(13))
                        .foregroundStyle(.gsTextSecondary)
                        .padding(.horizontal, AppSpacing.smallSpacing)
                        .padding(.vertical, AppSpacing.compactGap)
                        .background(.gsBackground)
                        .clipShape(Capsule())
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()
                .opacity(0.75)
            }
        }
    }

    private var newItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
            HStack(spacing: AppSpacing.smallSpacing) {
                Image(systemName: "plus.circle.fill")
                    .font(BrandSymbolFont.symbol(20))
                    .foregroundStyle(.gsSuccess)
                Text("New to your pantry")
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)

            ForEach(auditViewModel.unmatchedEntries) { entry in
                HStack {
                    Text(entry.shoppingItem.name)
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsTextPrimary)
                    Spacer()
                    if entry.shoppingItem.quantity > 1 {
                        Text("×\(Int(entry.shoppingItem.quantity))")
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()
            }
        }
    }
}
