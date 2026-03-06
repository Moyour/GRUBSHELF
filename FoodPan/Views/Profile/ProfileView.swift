import SwiftUI

private enum ExportFormat {
    case json, csv
}

struct ProfileView: View {
    @State var viewModel: ProfileViewModel
    @Binding var showSettings: Bool
    @State private var isExporting = false
    @State private var exportFileURL: URL?
    @State private var showExportSheet = false

    init(viewModel: ProfileViewModel, showSettings: Binding<Bool>) {
        _viewModel = State(initialValue: viewModel)
        _showSettings = showSettings
    }

    var body: some View {
        NavigationStack {
            Form {
                // User Info
                Section("Account") {
                    if let user = viewModel.currentUser {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.primaryGreen.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(AppFont.button)
                                    .foregroundStyle(Color.primaryGreen)
                            }
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(AppFont.button)
                                    .foregroundStyle(Color.primaryText)
                                Text(user.email)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }

                            Spacer()

                            Button {
                                viewModel.prepareEdit()
                            } label: {
                                Text("Edit")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.accentBlue)
                            }
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                        .accessibilityElement(children: .combine)

                        if !viewModel.householdName.isEmpty {
                            Label(viewModel.householdName, systemImage: "house.fill")
                                .font(AppFont.body)
                        }
                    }
                }

                // Family Members
                Section("Family") {
                    NavigationLink {
                        FamilyMembersView(
                            members: viewModel.members,
                            pendingInvites: viewModel.pendingInvites,
                            currentUserRole: viewModel.currentUser?.role ?? .member,
                            onToggleRole: { member in Task { await viewModel.toggleRole(member) } },
                            onRemove: { member in Task { await viewModel.removeMember(member) } },
                            onCancelInvite: { invite in Task { await viewModel.cancelInvite(invite) } },
                            onInviteTapped: { viewModel.showInviteSheet = true }
                        )
                    } label: {
                        HStack {
                            Label("\(viewModel.members.count) members", systemImage: "person.2.fill")
                            if !viewModel.pendingInvites.isEmpty {
                                Spacer()
                                Text("\(viewModel.pendingInvites.count) pending")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.warningAmber)
                            }
                        }
                    }
                }

                // Data Export
                Section("Data") {
                    Button {
                        Task { await exportData(format: .json) }
                    } label: {
                        Label("Export as JSON", systemImage: "doc.text")
                    }

                    Button {
                        Task { await exportData(format: .csv) }
                    } label: {
                        Label("Export as CSV", systemImage: "tablecells")
                    }
                }

                // Sign Out
                Section {
                    Button {
                        Task { await viewModel.signOut() }
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.errorRed)
                    }
                }

                // Delete Account
                Section {
                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task { await viewModel.loadData() }
            .sheet(isPresented: $viewModel.showInviteSheet) {
                InviteMemberSheet { email in
                    Task { await viewModel.inviteMember(email: email) }
                    DispatchQueue.main.async { viewModel.showInviteSheet = false }
                }
            }
            .sheet(item: $viewModel.shareInviteItem) { item in
                InviteShareSheet(item: item)
            }
            .sheet(isPresented: $viewModel.showEditProfile) {
                EditProfileSheet(viewModel: viewModel)
            }
            .alert("Delete Account?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportFileURL {
                    ExportShareSheet(fileURL: url)
                }
            }
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func exportData(format: ExportFormat) async {
        guard let user = viewModel.currentUser, let householdId = user.householdId else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let pantryRepo = SupabasePantryRepository()
            let shoppingRepo = SupabaseShoppingRepository()
            let shoppingListRepo = SupabaseShoppingListRepository()
            let wasteRepo = SupabaseWasteEventRepository()

            async let pantryFetch = pantryRepo.fetchAll(householdId: householdId)
            async let shoppingFetch = shoppingRepo.fetchAll(householdId: householdId)
            async let listsFetch = shoppingListRepo.fetchAll(householdId: householdId)
            async let wasteFetch = wasteRepo.fetchByDateRange(householdId: householdId, start: .distantPast, end: .now)

            let (pantryItems, shoppingItems, shoppingLists, wasteEvents) = try await (pantryFetch, shoppingFetch, listsFetch, wasteFetch)

            let tempDir = FileManager.default.temporaryDirectory

            switch format {
            case .json:
                let data = try DataExportService.exportJSON(
                    pantryItems: pantryItems,
                    shoppingLists: shoppingLists,
                    shoppingItems: shoppingItems,
                    wasteEvents: wasteEvents
                )
                let fileURL = tempDir.appendingPathComponent("FoodPan-Export.json")
                try data.write(to: fileURL)
                exportFileURL = fileURL
                showExportSheet = true

            case .csv:
                let csv = DataExportService.exportCSV(
                    pantryItems: pantryItems,
                    shoppingItems: shoppingItems,
                    wasteEvents: wasteEvents
                )
                let fileURL = tempDir.appendingPathComponent("FoodPan-Export.csv")
                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
                exportFileURL = fileURL
                showExportSheet = true
            }
        } catch {
            ToastManager.shared.show("Export failed: \(error.localizedDescription)", style: .error)
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    private var isAdmin: Bool {
        viewModel.currentUser?.role == .admin
    }

    private var hasChanges: Bool {
        let nameChanged = viewModel.editName.trimmingCharacters(in: .whitespacesAndNewlines) != (viewModel.currentUser?.name ?? "")
        let householdChanged = viewModel.editHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines) != viewModel.householdName
        return nameChanged || householdChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $viewModel.editName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                if isAdmin {
                    Section("Household Name") {
                        TextField("Household name", text: $viewModel.editHouseholdName)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    HStack {
                        Text("Email")
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        Text(viewModel.currentUser?.email ?? "")
                            .foregroundStyle(Color.secondaryText)
                    }
                } footer: {
                    Text("Email cannot be changed here.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            await viewModel.saveProfile()
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(!hasChanges || viewModel.editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}
