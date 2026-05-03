import SwiftUI

struct FamilyMembersView: View {
    let members: [AppUser]
    let pendingInvites: [HouseholdInvite]
    let currentUserRole: UserRole
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
        members.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section {
                if sortedInvites.isEmpty && sortedMembers.isEmpty {
                    Text("No members yet. Invite someone to share this household.")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                        .padding(.vertical, AppSpacing.smallSpacing)
                        .listRowBackground(Color.clear)
                }

                ForEach(sortedInvites) { invite in
                    inviteRow(invite)
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                ForEach(sortedMembers) { member in
                    memberRow(member)
                        .listRowInsets(AppSpacing.listRowCardInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Household")
                    Spacer()
                    if !sortedInvites.isEmpty {
                        Text("\(sortedInvites.count) pending")
                            .font(BrandFont.medium(13))
                            .foregroundStyle(.gsBrandPrimary)
                    }
                }
                .foregroundStyle(.gsTextSecondary)
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
            if currentUserRole == .admin {
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

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(invite.invitedEmail)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)

                if expired {
                    Text("Invite expired — send a new one or cancel this row.")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsWarning)
                } else {
                    Text("Waiting to join · Expires \(invite.expiresAt, style: .relative)")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                }
            }

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
            if currentUserRole == .admin {
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

            VStack(alignment: .leading, spacing: AppSpacing.microGap) {
                Text(member.name)
                    .font(BrandFont.semiBold(17))
                    .foregroundStyle(.gsTextPrimary)

                Text(member.email)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
            }

            Spacer(minLength: AppSpacing.smallSpacing)

            Text(member.role.rawValue.capitalized)
                .font(BrandFont.medium(13))
                .padding(.horizontal, AppSpacing.smallSpacing)
                .padding(.vertical, AppSpacing.compactGap)
                .background(member.role == .admin ? .gsBrandPrimary.opacity(0.15) : .gsBackground)
                .foregroundStyle(member.role == .admin ? .gsBrandPrimary : .gsTextSecondary)
                .clipShape(Capsule())
        }
        .padding(AppSpacing.cardPadding)
        .frame(minHeight: AppSpacing.minTouchTarget)
        .dashboardCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), \(member.email), \(member.role.rawValue)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if currentUserRole == .admin {
                Button(role: .destructive) { memberToRemove = member } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                }
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

    private func statusLabel(_ status: HouseholdInvite.InviteStatus) -> String {
        switch status {
        case .pending: "Pending"
        case .accepted: "Joined"
        case .cancelled: "Cancelled"
        }
    }
}
