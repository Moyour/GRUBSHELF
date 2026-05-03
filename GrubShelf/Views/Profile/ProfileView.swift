import SwiftUI

private enum ExportFormat {
    case json, csv
}

struct ProfileView: View {
    @State var viewModel: ProfileViewModel
    /// Presented here (not from the tab root) so Settings opens reliably while Profile is already a sheet.
    @State private var showSettings = false
    @State private var isExporting = false
    @State private var exportFileURL: URL?
    @State private var showExportSheet = false

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
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
                                    .fill(.gsBrandPrimary.opacity(0.15))
                                    .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                                Text(user.name)
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                                Text(user.email)
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                            }

                            Spacer()

                            Button {
                                viewModel.prepareEdit()
                            } label: {
                                Text("Edit")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                        .accessibilityElement(children: .combine)

                        if !viewModel.householdName.isEmpty {
                            Label {
                                Text(viewModel.householdName)
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "house.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                    }
                }

                // Settings (opens app settings sheet)
                Section {
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: AppSpacing.rowSpacing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppSpacing.iconRadius)
                                    .fill(.gsBrandPrimary.opacity(0.15))
                                    .frame(width: AppSpacing.iconSizeSmall, height: AppSpacing.iconSizeSmall)
                                Image(systemName: "gearshape.fill")
                                    .font(BrandSymbolFont.symbol(20))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                                Text("Settings")
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                                Text("Notifications, reminders, help & legal")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsTextSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: AppSpacing.smallSpacing)
                            Image(systemName: "chevron.right")
                                .font(BrandSymbolFont.symbol(12, weight: .semibold))
                                .foregroundStyle(.gsTextSecondary.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
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
                            onInviteTapped: { viewModel.showInviteSheet = true },
                            onRefresh: { await viewModel.loadData(forceRefresh: true) }
                        )
                    } label: {
                        HStack {
                            Label {
                                Text("\(viewModel.members.count) members")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "person.2.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            if !viewModel.pendingInvites.isEmpty {
                                Spacer()
                                Text("\(viewModel.pendingInvites.count) pending")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                    }
                }

                // Data Export
                Section("Data") {
                    Button {
                        Task { await exportData(format: .json) }
                    } label: {
                        Label {
                            Text("Export as JSON")
                                .font(BrandFont.regular(17))
                                .foregroundStyle(.gsTextPrimary)
                        } icon: {
                            Image(systemName: "doc.text")
                                .font(BrandSymbolFont.symbol(17))
                                .foregroundStyle(.gsBrandPrimary)
                        }
                    }

                    Button {
                        Task { await exportData(format: .csv) }
                    } label: {
                        Label {
                            Text("Export as CSV")
                                .font(BrandFont.regular(17))
                                .foregroundStyle(.gsTextPrimary)
                        } icon: {
                            Image(systemName: "tablecells")
                                .font(BrandSymbolFont.symbol(17))
                                .foregroundStyle(.gsBrandPrimary)
                        }
                    }
                }

                // Sign Out
                Section {
                    Button {
                        Task { await viewModel.signOut() }
                    } label: {
                        Text("Sign out")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.gsBrandPrimary)
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
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Profile")
            .task { await viewModel.loadData() }
            .sheet(isPresented: $showSettings) {
                SettingsView(householdId: viewModel.currentUser?.householdId, profileVM: viewModel)
            }
            .sheet(isPresented: $viewModel.showInviteSheet) {
                InviteMemberSheet { email in
                    Task { await viewModel.inviteMember(email: email) }
                }
            }
            .sheet(isPresented: $viewModel.showEditProfile) {
                EditProfileSheet(viewModel: viewModel)
            }
            .alert("Remove account?", isPresented: $viewModel.showDeleteConfirmation) {
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
                        .tint(.gsBrandPrimary)
                        .foregroundStyle(.gsTextPrimary)
                        .padding(AppSpacing.cardPadding)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
            }
            .tint(.gsBrandPrimary)
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
                let fileURL = tempDir.appendingPathComponent("Grub-Shelf-Export.json")
                try data.write(to: fileURL)
                exportFileURL = fileURL
                showExportSheet = true

            case .csv:
                let csv = DataExportService.exportCSV(
                    pantryItems: pantryItems,
                    shoppingItems: shoppingItems,
                    wasteEvents: wasteEvents
                )
                let fileURL = tempDir.appendingPathComponent("Grub-Shelf-Export.csv")
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
                            .foregroundStyle(.gsTextSecondary)
                        Spacer()
                        Text(viewModel.currentUser?.email ?? "")
                            .foregroundStyle(.gsTextSecondary)
                    }
                } footer: {
                    Text("Email cannot be changed here.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges)
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
            .tint(.gsBrandPrimary)
        }
    }
}
