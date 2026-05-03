import SwiftUI

struct CreateShoppingListSheet: View {
    @Bindable var viewModel: ShoppingListsViewModel
    /// Called with the persisted list when creation succeeds, before the sheet dismisses.
    var onCreated: ((ShoppingList) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("List name", text: $viewModel.newListName)
                        .font(BrandFont.regular(17))
                        .focused($nameFieldFocused)
                        .onSubmit { createAndDismiss() }
                        .submitLabel(.done)
                        .padding(AppSpacing.cardPadding)
                        .dashboardCardSurface()
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Name")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("New shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createAndDismiss() }
                        .disabled(viewModel.newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func createAndDismiss() {
        Task {
            if let list = await viewModel.createList() {
                onCreated?(list)
            }
            dismiss()
        }
    }
}
