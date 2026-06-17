import StoreKit
import SwiftUI

struct ProfileView: View {
    @State var viewModel: ProfileViewModel
    /// Presented here (not from the tab root) so Settings opens reliably while Profile is already a sheet.
    @State private var showSettings = false
    @State private var isExporting = false
    @State private var exportFileURL: URL?
    @State private var showExportSheet = false
    @Environment(\.featureGateService) private var featureGateService
    @Environment(\.subscriptionService) private var subscriptionService

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
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

                            Text(user.name)
                                .font(BrandFont.semiBold(17))
                                .foregroundStyle(.gsTextPrimary)

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

                // Family Members
                Section("Family") {
                    if viewModel.members.isEmpty && !viewModel.isLoading {
                        Text("No family members yet. Go to 'All members & invites' to invite someone.")
                            .font(BrandFont.regular(15))
                            .foregroundStyle(.gsTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, AppSpacing.smallSpacing)
                    } else {
                        // Show all members ordered: owner → other admins → members (alphabetical within each tier)
                        ForEach(
                            Array(
                                viewModel.members
                                    .sorted(by: AppUser.householdOrder)
                                    .prefix(3)
                            )
                        ) { member in
                            HStack {
                                Text(member.name)
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                                Spacer()
                                Text(MemberRoleLabel.display(for: member))
                                    .font(BrandFont.medium(13))
                                    .foregroundStyle(
                                        member.isOwner || member.role == .admin
                                            ? .gsBrandPrimary
                                            : .gsTextSecondary
                                    )
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(member.name), \(MemberRoleLabel.display(for: member))")
                        }
                    }

                    ForEach(
                        viewModel.pendingInvites
                            .sorted { $0.createdAt > $1.createdAt }
                    ) { invite in
                        HStack(spacing: AppSpacing.smallSpacing) {
                            Text(invite.invitedEmail)
                                .font(BrandFont.medium(15))
                                .foregroundStyle(.gsTextPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: AppSpacing.smallSpacing)
                            Text(invite.isExpired ? "Expired" : "Pending")
                                .font(BrandFont.medium(13))
                                .foregroundStyle(invite.isExpired ? .gsWarning : .gsTextSecondary)
                        }
                        .accessibilityLabel("\(invite.invitedEmail), \(invite.isExpired ? "expired invite" : "pending invite")")
                    }

                    NavigationLink {
                        FamilyMembersView(
                            members: viewModel.members,
                            pendingInvites: viewModel.pendingInvites,
                            currentUserRole: viewModel.currentUser?.role ?? .member,
                            currentUserIsOwner: viewModel.currentUser?.isOwner ?? false,
                            onToggleRole: { member in Task { await viewModel.toggleRole(member) } },
                            onRemove: { member in Task { await viewModel.removeMember(member) } },
                            onCancelInvite: { invite in Task { await viewModel.cancelInvite(invite) } },
                            onInviteTapped: {
                                if viewModel.canInviteMembers {
                                    viewModel.showInviteSheet = true
                                }
                            },
                            onRefresh: { await viewModel.loadData(forceRefresh: true) }
                        )
                    } label: {
                        HStack {
                            Label {
                                Text("All members & invites")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "person.2.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            Spacer()
                            Text("\(viewModel.members.count) joined")
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsTextSecondary)
                            if !viewModel.pendingInvites.isEmpty {
                                Text("· \(viewModel.pendingInvites.count) pending")
                                    .font(BrandFont.regular(14))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                    }
                }

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
                } header: {
                    Text("Settings")
                }

                // Subscription
                Section("Subscription") {
                    if subscriptionService?.isPremium == true {
                        HStack {
                            Label {
                                Text("Premium")
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                            Spacer()
                            Text("Active")
                                .font(BrandFont.medium(13))
                                .foregroundStyle(.gsSuccess)
                        }
                        Button {
                            Task {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    try? await AppStore.showManageSubscriptions(in: windowScene)
                                }
                            }
                        } label: {
                            Label {
                                Text("Manage Subscription")
                                    .font(BrandFont.regular(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "gearshape")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsBrandPrimary)
                            }
                        }
                    } else {
                        HStack {
                            Label {
                                Text("Free")
                                    .font(BrandFont.semiBold(17))
                                    .foregroundStyle(.gsTextPrimary)
                            } icon: {
                                Image(systemName: "gift")
                                    .font(BrandSymbolFont.symbol(17))
                                    .foregroundStyle(.gsTextSecondary)
                            }
                            Spacer()
                            Button {
                                featureGateService?.showPaywall = true
                            } label: {
                                Text("Upgrade")
                                    .font(BrandFont.semiBold(14))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.gsBrandPrimary)
                        }
                    }
                }

                // Data Export
                Section("Data") {
                    Button {
                        guard featureGateService?.requireFeature(.exportReports) != false else { return }
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
                        guard featureGateService?.requireFeature(.exportReports) != false else { return }
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
            .refreshable {
                await viewModel.loadData(forceRefresh: true)
            }
            .overlay {
                if viewModel.isLoading && viewModel.members.isEmpty {
                    ProgressView("Loading...")
                        .tint(.gsBrandPrimary)
                        .foregroundStyle(.gsTextPrimary)
                        .padding(AppSpacing.cardPadding)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(householdId: viewModel.currentUser?.householdId, profileVM: viewModel)
            }
            .sheet(isPresented: $viewModel.showInviteSheet) {
                if viewModel.canInviteMembers {
                    InviteMemberSheet { email in
                        await viewModel.inviteMember(email: email)
                    }
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
            .sheet(item: $viewModel.pendingShareInvite) { invite in
                InviteShareSheet(activityItems: viewModel.inviteShareItems(for: invite))
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
        .toastOverlay()
    }

    private func exportData(format: ExportFormat) async {
        guard let user = viewModel.currentUser, let householdId = user.householdId else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            exportFileURL = try await DataExportService.exportToFile(format: format, householdId: householdId)
            showExportSheet = true

            // Audit log (best-effort)
            _ = try? await SupabaseManager.shared.client.rpc("log_audit_event", params: [
                "p_action": "data_export",
                "p_target_entity": "household",
                "p_target_id": householdId.uuidString,
                "p_metadata": "{\"format\": \"\(format.rawValue)\"}",
            ]).execute()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "export data"),
                style: .error
            )
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
