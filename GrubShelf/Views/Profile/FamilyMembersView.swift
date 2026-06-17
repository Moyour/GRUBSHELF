import SwiftUI

struct FamilyMembersView: View {
    let members: [AppUser]
    let pendingInvites: [HouseholdInvite]
    let currentUserRole: UserRole
    let currentUserIsOwner: Bool
    let onToggleRole: (AppUser) -> Void
    let onRemove: (AppUser) -> Void
    let onCancelInvite: (HouseholdInvite) -> Void
    let onInviteTapped: () -> Void
    var onRefresh: (() async -> Void)?

    @State private var memberToRemove: AppUser?
    @State private var inviteToCancel: HouseholdInvite?

    private var sortedInvites: [HouseholdInvite] {
        pendingInvites.sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedMembers: [AppUser] {
        members.sorted(by: AppUser.householdOrder)
    }

    private var hasAnyRows: Bool {
        !sortedInvites.isEmpty || !sortedMembers.isEmpty
    }

    var body: some View {
        List {
            if !hasAnyRows {
                Section {
                    Text("No members yet. Invite someone to share this household.")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                        .padding(.vertical, AppSpacing.smallSpacing)
                        .listRowBackground(Color.clear)
                }
            }

            if !sortedMembers.isEmpty {
                Section {
                    ForEach(sortedMembers) { member in
                        memberRow(member)
                            .listRowInsets(AppSpacing.listRowCardInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Members")
                } footer: {
                    if PermissionService.canPerform(.manageMembers, role: currentUserRole, isOwner: currentUserIsOwner) {
                        Text("Swipe a row to manage roles, remove members, or cancel invites.")
                            .font(BrandFont.regular(13))
                    }
                }
            }

            if !sortedInvites.isEmpty {
                Section {
                    ForEach(sortedInvites) { invite in
                        inviteRow(invite)
                            .listRowInsets(AppSpacing.listRowCardInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Invited")
                } footer: {
                    Text("Pending means they aren’t in the household yet. They need GrubShelf and must sign in with the invited email to join.")
                        .font(BrandFont.regular(13))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.gsBackground)
        .navigationTitle("Family members")
        .task {
            await onRefresh?()
        }
        .refreshable {
            await onRefresh?()
        }
        .toolbar {
            if PermissionService.canPerform(.manageMembers, role: currentUserRole, isOwner: currentUserIsOwner) {
                ToolbarItem(placement: .topBarTrailing) {
                    PrimaryToolbarIconButton(
                        systemImage: "person.badge.plus",
                        accessibilityLabel: "Invite family member",
                        accessibilityHint: "Add a family member by email"
                    ) {
                        onInviteTapped()
                    }
                }
            }
        }
        .tint(.gsBrandPrimary)
        .alert("Remove member?", isPresented: .init(
            get: { memberToRemove != nil },
            set: { if !$0 { memberToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let member = memberToRemove { onRemove(member) }
            }
            Button("Cancel", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("\(memberToRemove?.name ?? "") will be removed from this household.")
        }
        .alert("Cancel invite?", isPresented: .init(
            get: { inviteToCancel != nil },
            set: { if !$0 { inviteToCancel = nil } }
        )) {
            Button("Cancel invite", role: .destructive) {
                if let invite = inviteToCancel { onCancelInvite(invite) }
            }
            Button("Keep", role: .cancel) { inviteToCancel = nil }
        } message: {
            Text("The invitation to \(inviteToCancel?.invitedEmail ?? "") will be revoked.")
        }
    }

    // MARK: - Rows

    private func inviteRow(_ invite: HouseholdInvite) -> some View {
        let expired = invite.isExpired
        return HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.badgeCornerRadius, style: .continuous)
                    .fill((expired ? Color.gsWarning : Color.gsBrandPrimary).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "envelope.badge.fill")
                    .font(BrandSymbolFont.symbol(20, weight: .semibold))
                    .foregroundStyle(expired ? .gsWarning : .gsBrandPrimary)
            }

            Text(invite.invitedEmail)
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: AppSpacing.smallSpacing)

            Text(expired ? "Expired" : statusLabel(invite.status))
                .font(BrandFont.medium(13))
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(
                    expired ? Color.gsWarning.opacity(0.15) : Color.gsBrandPrimary.opacity(0.15)
                )
                .foregroundStyle(expired ? .gsWarning : .gsBrandPrimary)
                .clipShape(Capsule())
        }
        .padding(AppSpacing.cardPadding)
        .frame(minHeight: AppSpacing.minTouchTarget)
        .dashboardCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(invite.invitedEmail), \(expired ? "expired invite" : "pending invite")")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if PermissionService.canPerform(.manageMembers, role: currentUserRole, isOwner: currentUserIsOwner) {
                Button(role: .destructive) {
                    inviteToCancel = invite
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            }
        }
    }

    private func memberRow(_ member: AppUser) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.rowSpacing) {
            ZStack {
                Circle()
                    .fill(.gsBrandPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(member.name.prefix(1)).uppercased())
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsBrandPrimary)
            }
            .accessibilityHidden(true)

            Text(member.name)
                .font(BrandFont.semiBold(17))
                .foregroundStyle(.gsTextPrimary)

            Spacer(minLength: AppSpacing.smallSpacing)

            Text(memberRoleLabel(member))
                .font(BrandFont.medium(13))
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(
                    member.isOwner || member.role == .admin
                        ? .gsBrandPrimary.opacity(0.15)
                        : .gsBackground
                )
                .foregroundStyle(
                    member.isOwner || member.role == .admin
                        ? .gsBrandPrimary
                        : .gsTextSecondary
                )
                .clipShape(Capsule())
        }
        .padding(AppSpacing.cardPadding)
        .frame(minHeight: AppSpacing.minTouchTarget)
        .dashboardCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), \(memberRoleLabel(member))")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if PermissionService.canPerform(.manageMembers, role: currentUserRole, isOwner: currentUserIsOwner),
               !member.isOwner {
                Button(role: .destructive) { memberToRemove = member } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                }
            }
            if currentUserIsOwner, !member.isOwner {
                Button { onToggleRole(member) } label: {
                    Label(
                        member.role == .admin ? "Demote" : "Promote",
                        systemImage: member.role == .admin ? "arrow.down" : "arrow.up"
                    )
                }
                .tint(.gsBrandPrimary)
            }
        }
    }

    private func memberRoleLabel(_ member: AppUser) -> String {
        MemberRoleLabel.display(for: member)
    }

    private func statusLabel(_ status: HouseholdInvite.InviteStatus) -> String {
        switch status {
        case .pending: "Pending"
        case .approved: "Approved"
        case .rejected: "Rejected"
        case .accepted: "Joined"
        case .cancelled: "Cancelled"
        case .expired: "Expired"
        }
    }
}
