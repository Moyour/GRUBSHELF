import SwiftUI

struct CreateShoppingListSheet: View {
    @Bindable var viewModel: ShoppingListsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List name", text: $viewModel.newListName)
                        .font(AppFont.body)
                        .focused($nameFieldFocused)
                        .onSubmit { createAndDismiss() }
                        .submitLabel(.done)
                } header: {
                    Text("Name")
                }
            }
            .navigationTitle("New Shopping List")
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
            await viewModel.createList()
            dismiss()
        }
    }
}
