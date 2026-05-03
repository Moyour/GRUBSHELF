import SwiftUI

struct PantryReviewView: View {
    @State private var viewModel: PantryReviewViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PantryReviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.staleItems.isEmpty {
                    allCaughtUpView
                } else {
                    reviewList
                }
            }
            .navigationTitle("Pantry review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.staleItems.count >= 2 {
                        Button("Confirm all") {
                            Task { await viewModel.confirmAllStillHave() }
                        }
                        .font(BrandFont.regular(14))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(BrandFont.semiBold(17))
                }
            }
            .tint(.gsBrandPrimary)
            .background(.gsBackground)
            .confirmationDialog(
                "What happened to \(viewModel.itemToRemove?.name ?? "this item")?",
                isPresented: $viewModel.showRemovalPrompt,
                titleVisibility: .visible
            ) {
                Button("Used it") {
                    Task { await viewModel.confirmUsed() }
                }
                Button("Remove from list", role: .destructive) {
                    Task { await viewModel.confirmRemoveFromList() }
                }
                Button("Expired", role: .destructive) {
                    viewModel.beginExpiredRemoval()
                }
                Button("Waste", role: .destructive) {
                    viewModel.beginWasteRemoval()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRemovalFlow()
                }
            }
            .alert("Estimated cost (optional)", isPresented: $viewModel.showWasteCostPrompt) {
                TextField("Amount", text: $viewModel.wasteCostText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    Task { await viewModel.saveWasteEvent() }
                }
                Button("Skip") {
                    Task { await viewModel.saveWasteEvent(skipCost: true) }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRemovalFlow()
                }
            }
        }
    }

    private var allCaughtUpView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(BrandSymbolFont.symbol(34, weight: .bold))
                .foregroundStyle(.gsBrandPrimary)
            Text("All good")
                .font(BrandFont.semiBold(18))
                .foregroundStyle(.gsTextPrimary)
            Text("Nothing needs attention right now")
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var reviewList: some View {
        List {
            ForEach(viewModel.groupedByCategory, id: \.category) { group in
                Section {
                    ForEach(group.items) { item in
                        reviewRow(item)
                    }
                } header: {
                    HStack {
                        Text(group.category)
                            .font(BrandFont.semiBold(18))
                        Spacer()
                        Text("\(group.items.count)")
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsTextSecondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func reviewRow(_ item: PantryItem) -> some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                Text(item.name)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.denseSpacing) {
                    Label(
                        "\(item.quantity.formatted()) \(item.unit.abbreviation)",
                        systemImage: "scalemass"
                    )
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)

                    Text("·")
                        .foregroundStyle(.gsTextSecondary)

                    Text("\(item.daysSinceLastUpdate)d since update")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsBrandPrimary)
                }
            }

            Spacer()

            HStack(spacing: AppSpacing.smallSpacing) {
                Button {
                    Task { await viewModel.markStillHaveIt(item) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(BrandSymbolFont.symbol(22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.gsBrandPrimary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Still have it")

                Button {
                    viewModel.markFinished(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(BrandSymbolFont.symbol(22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.gsTextSecondary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Finished")
            }
        }
        .padding(AppSpacing.cardPadding)
        .accessibilityElement(children: .combine)
        .dashboardCardSurface()
        .listRowInsets(AppSpacing.listRowCardInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
