import SwiftUI
import Supabase

struct CreateHouseholdView: View {
    @Bindable var authService: AuthenticationService
    @State private var householdName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingInvites: [HouseholdInviteWithName] = []
    @State private var isLoadingInvites = true
    @State private var acceptingInviteId: UUID?

    private let householdService = HouseholdService()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                Spacer(minLength: 40)

                // Pending invites section
                if isLoadingInvites {
                    ProgressView()
                        .padding()
                } else if !pendingInvites.isEmpty {
                    invitesSection
                }

                // Create household section
                createSection

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
        .task {
            await loadInvites()
        }
    }

    // MARK: - Invites Section

    private var invitesSection: some View {
        VStack(spacing: AppSpacing.rowSpacing) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: AppFont.emptyStateIconSizeSecondary))
                .foregroundStyle(Color.primaryGreen)

            Text("You've Been Invited!")
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.primaryText)

            ForEach(pendingInvites) { invite in
                VStack(spacing: AppSpacing.rowSpacing) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invite.householdName)
                                .font(AppFont.button)
                                .foregroundStyle(Color.primaryText)
                            Text("Invited to join this household")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .cardShadow()

                    Button {
                        Task { await acceptInvite(invite) }
                    } label: {
                        if acceptingInviteId == invite.inviteId {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.minTouchTarget)
                        } else {
                            Text("Join \(invite.householdName)")
                                .font(AppFont.button)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.minTouchTarget)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primaryGreen)
                    .disabled(acceptingInviteId != nil)
                }
            }

            dividerRow
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private var dividerRow: some View {
        HStack(spacing: AppSpacing.rowSpacing) {
            Rectangle()
                .fill(Color.divider)
                .frame(height: 1)
            Text("or")
                .font(AppFont.caption)
                .foregroundStyle(Color.secondaryText)
            Rectangle()
                .fill(Color.divider)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Create Section

    private var createSection: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: AppFont.emptyStateIconSize))
                .foregroundStyle(Color.primaryGreen)

            Text("Create Your Household")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.primaryText)

            Text("Give your household a name so your family can find it.")
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenPadding)

            TextField("Household name", text: $householdName)
                .font(AppFont.body)
                .padding()
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                        .stroke(Color.divider, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenPadding)

            if let error = errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.errorRed)
            }

            Button {
                Task { await createHousehold() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                } else {
                    Text("Create Household")
                        .font(AppFont.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryGreen)
            .disabled(householdName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Actions

    private func loadInvites() async {
        guard let email = authService.currentUser?.email else {
            isLoadingInvites = false
            return
        }
        do {
            pendingInvites = try await householdService.fetchInvitesForEmail(email: email)
        } catch {
            // Non-critical — just won't show invites
        }
        isLoadingInvites = false
    }

    private func acceptInvite(_ invite: HouseholdInviteWithName) async {
        acceptingInviteId = invite.inviteId
        errorMessage = nil
        do {
            let updatedUser = try await householdService.acceptInvite(inviteId: invite.inviteId)
            authService.currentUser = updatedUser
            ToastManager.shared.show("Joined \(invite.householdName)!", style: .success)
        } catch {
            errorMessage = error.localizedDescription
        }
        acceptingInviteId = nil
    }

    private func createHousehold() async {
        isLoading = true
        errorMessage = nil

        let household = Household(
            householdId: UUID(),
            name: householdName.trimmingCharacters(in: .whitespaces),
            planType: nil,
            createdAt: .now
        )

        do {
            let client = SupabaseManager.shared.client

            try await client.from("households").insert(household).execute()

            if let user = authService.currentUser {
                let rows: [AppUser] = try await client.rpc("ensure_user_profile", params: [
                    "p_user_id": user.userId.uuidString,
                    "p_name": user.name,
                    "p_email": user.email,
                    "p_household_id": household.householdId.uuidString,
                    "p_role": "admin",
                ]).execute().value

                authService.currentUser = rows.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
