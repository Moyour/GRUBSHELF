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
            .navigationTitle("Pantry Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.button)
                }
            }
            .background(Color.appBackground)
            .confirmationDialog(
                "What happened to \(viewModel.itemToRemove?.name ?? "this item")?",
                isPresented: $viewModel.showRemovalPrompt,
                titleVisibility: .visible
            ) {
                Button("Used it") {
                    Task { await viewModel.confirmUsed() }
                }
                Button("Wasted / Expired", role: .destructive) {
                    Task { await viewModel.confirmWasted() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.itemToRemove = nil
                }
            }
        }
    }

    private var allCaughtUpView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: AppFont.emptyStateIconSize))
                .foregroundStyle(Color.successGreen)
            Text("All Caught Up!")
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.primaryText)
            Text("No items need review right now.")
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
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
                            .font(AppFont.sectionTitle)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func reviewRow(_ item: PantryItem) -> some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppFont.button)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(
                        "\(item.quantity.formatted()) \(item.unit.abbreviation)",
                        systemImage: "scalemass"
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)

                    Text("·")
                        .foregroundStyle(Color.secondaryText)

                    Text("\(item.daysSinceLastUpdate)d since update")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.accentBlue)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.markStillHaveIt(item) }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color.successGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Still have it")

                Button {
                    viewModel.markFinished(item)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color.errorRed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Finished")
            }
        }
        .padding(.vertical, AppSpacing.smallSpacing)
        .accessibilityElement(children: .combine)
    }
}
