import SwiftUI

struct FamilyMembersView: View {
    let members: [AppUser]
    let pendingInvites: [HouseholdInvite]
    let currentUserRole: UserRole
    let onToggleRole: (AppUser) -> Void
    let onRemove: (AppUser) -> Void
    let onCancelInvite: (HouseholdInvite) -> Void
    let onInviteTapped: () -> Void

    var body: some View {
        List {
            if !pendingInvites.isEmpty {
                Section {
                    ForEach(pendingInvites) { invite in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invite.invitedEmail)
                                    .font(AppFont.button)
                                    .foregroundStyle(Color.primaryText)

                                Text("Expires \(invite.expiresAt, style: .relative) from now")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }

                            Spacer()

                            Text("Pending")
                                .font(AppFont.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.warningAmber.opacity(0.15))
                                .foregroundStyle(Color.warningAmber)
                                .clipShape(Capsule())
                        }
                        .frame(minHeight: AppSpacing.minTouchTarget)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if currentUserRole == .admin {
                                Button(role: .destructive) {
                                    onCancelInvite(invite)
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Pending Invites")
                }
            }

            Section {
                ForEach(members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(AppFont.button)
                                .foregroundStyle(Color.primaryText)

                            Text(member.email)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                        }

                        Spacer()

                        Text(member.role.rawValue.capitalized)
                            .font(AppFont.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(member.role == .admin ? Color.primaryGreen.opacity(0.15) : Color.appBackground)
                            .foregroundStyle(member.role == .admin ? Color.primaryGreen : Color.secondaryText)
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(member.name), \(member.email), \(member.role.rawValue)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if currentUserRole == .admin {
                            Button(role: .destructive) { onRemove(member) } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                            Button { onToggleRole(member) } label: {
                                Label(
                                    member.role == .admin ? "Demote" : "Promote",
                                    systemImage: member.role == .admin ? "arrow.down" : "arrow.up"
                                )
                            }
                            .tint(.orange)
                        }
                    }
                }
            } header: {
                Text("Members")
            }
        }
        .navigationTitle("Family Members")
        .toolbar {
            if currentUserRole == .admin {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onInviteTapped()
                    } label: {
                        Label("Invite", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }
}
