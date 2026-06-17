import SwiftUI

struct AddEditPantryItemView: View {
    @State var viewModel: AddEditPantryItemViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    var onDelete: ((UUID) -> Void)?

    init(viewModel: AddEditPantryItemViewModel, onDelete: ((UUID) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section {
                    TextField("Item name", text: $viewModel.name)
                        .autocorrectionDisabled()
                    if viewModel.isRecognizingFromPhoto {
                        HStack {
                            ProgressView()
                            Text(String(localized: "Identifying…"))
                                .font(BrandFont.regular(15))
                                .foregroundStyle(.gsTextSecondary)
                        }
                    }
                    if let preview = viewModel.recognizedPhotoPreview {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: AppSpacing.photoThumbnailSize, height: AppSpacing.photoThumbnailSize)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius))
                            VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                                Text(String(localized: "Photo ready for recognition"))
                                    .font(BrandFont.semiBold(14))
                                    .foregroundStyle(.gsTextPrimary)
                                if let badge = viewModel.recognitionBadgeStatus,
                                   let confidence = viewModel.lastRecognitionConfidence {
                                    HStack(spacing: AppSpacing.denseSpacing) {
                                        StatusBadgeView(status: badge)
                                        Text("\(Int((confidence * 100).rounded()))%")
                                            .font(BrandFont.mono(13))
                                            .foregroundStyle(.gsTextSecondary)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                    if !viewModel.photoRecognitionSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                            Text(String(localized: "Suggestions"))
                                .font(BrandFont.semiBold(13))
                                .foregroundStyle(.gsTextSecondary)
                            HStack(spacing: AppSpacing.denseSpacing) {
                                ForEach(viewModel.photoRecognitionSuggestions.prefix(3), id: \.self) { suggestion in
                                    Button {
                                        viewModel.applyPhotoRecognitionSuggestion(suggestion)
                                    } label: {
                                        Text(suggestion)
                                            .font(BrandFont.semiBold(13))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .padding(.horizontal, AppSpacing.smallSpacing)
                                            .padding(.vertical, AppSpacing.compactGap)
                                            .background(.gsBackground)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Use suggestion \(suggestion)")
                                }
                            }
                        }
                    }
                    if let hint = viewModel.photoRecognitionHint {
                        Text(hint)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(viewModel.photoRecognitionHintIsError ? .gsDanger : .gsTextSecondary)
                    }
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

                // Storage
                Section {
                    Picker("Stored in", selection: $viewModel.selectedStorageLocation) {
                        ForEach(PantryStorageLocation.allCases, id: \.self) { loc in
                            Text(loc.displayName).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Location")
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
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                    }
                }

                // Delete button (only when editing)
                if viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Item")
                                    .font(BrandFont.semiBold(16))
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .alert("Delete this item?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        let deletedId = viewModel.deletingItemId
                        if await viewModel.delete() {
                            if let deletedId { onDelete?(deletedId) }
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \(viewModel.name) from your pantry.")
            }
            .navigationTitle(viewModel.isEditing ? "Edit item" : "Add item")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !viewModel.isEditing {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                Task {
                                    if await viewModel.save() {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            Button {
                                Task {
                                    if await viewModel.save() {
                                        viewModel.resetForAnotherItem()
                                    }
                                }
                            } label: {
                                Label("Save & add another", systemImage: "plus.circle")
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        } primaryAction: {
                            Task {
                                if await viewModel.save() {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(viewModel.isLoading || viewModel.isRecognizingFromPhoto)
                    }
                } else {
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
                        .disabled(viewModel.isLoading || viewModel.isRecognizingFromPhoto)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func validationText(for field: String) -> some View {
        let matching = viewModel.validationErrors.filter { $0.contains(field) }
        ForEach(matching, id: \.self) { error in
            Text(error)
                .font(BrandFont.regular(14))
                .foregroundStyle(.gsDanger)
        }
    }
}
