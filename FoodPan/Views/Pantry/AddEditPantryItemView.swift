import SwiftUI

struct AddEditPantryItemView: View {
    @State var viewModel: AddEditPantryItemViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section {
                    TextField("Item name", text: $viewModel.name)
                        .autocorrectionDisabled()
                    validationText(for: "Name")
                } header: {
                    Text("Name")
                }

                // Quantity & Unit
                Section {
                    HStack {
                        TextField("Quantity", text: $viewModel.quantity)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $viewModel.selectedUnit) {
                            ForEach(UnitType.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                    validationText(for: "Quantity")
                } header: {
                    Text("Quantity")
                }

                // Expiry Date
                Section {
                    Toggle("Has expiry date", isOn: $viewModel.hasExpiry)
                    if viewModel.hasExpiry {
                        DatePicker(
                            "Expiry date",
                            selection: $viewModel.expiryDate,
                            displayedComponents: .date
                        )
                    }
                    validationText(for: "Expiry")
                }

                // Category
                Section {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(AddEditPantryItemViewModel.predefinedCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Text("Custom").tag("Custom")
                    }

                    if viewModel.category == "Custom" {
                        TextField("Custom category", text: $viewModel.customCategory)
                    }
                    validationText(for: "Category")
                } header: {
                    Text("Category")
                }

                // Errors
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.errorRed)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private func validationText(for field: String) -> some View {
        let matching = viewModel.validationErrors.filter { $0.contains(field) }
        ForEach(matching, id: \.self) { error in
            Text(error)
                .font(AppFont.caption)
                .foregroundStyle(Color.errorRed)
        }
    }
}
