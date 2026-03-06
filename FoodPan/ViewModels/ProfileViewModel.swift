import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var currentUser: AppUser?
    var householdName = ""
    var members: [AppUser] = []
    var pendingInvites: [HouseholdInvite] = []
    var expiryReminders = true
    var lowStockReminders = true
    var isLoading = false
    var showDeleteConfirmation = false
    var showInviteSheet = false
    var showEditProfile = false
    var editName = ""
    var editHouseholdName = ""
    var shareInviteItem: InviteShareItem?
    private let authService: AuthenticationService
    private let householdService: HouseholdService
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    init(
        authService: AuthenticationService,
        householdService: HouseholdService = HouseholdService()
    ) {
        self.authService = authService
        self.householdService = householdService
        self.currentUser = authService.currentUser

        expiryReminders = UserDefaults.standard.object(forKey: "expiryReminders") as? Bool ?? true
        lowStockReminders = UserDefaults.standard.object(forKey: "lowStockReminders") as? Bool ?? true
    }

    func loadData(forceRefresh: Bool = false) async {
        guard let user = authService.currentUser, let hid = user.householdId else { return }
        if !forceRefresh, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.cacheTTL {
            return
        }
        isLoading = true

        do {
            async let householdFetch = householdService.fetchHousehold(id: hid)
            async let membersFetch = householdService.fetchMembers(householdId: hid)
            let (household, fetchedMembers) = try await (householdFetch, membersFetch)
            householdName = household.name
            members = fetchedMembers
        } catch {
            ToastManager.shared.show("Failed to load profile", style: .error)
        }

        // Invites are best-effort — don't block or error if the table isn't set up yet
        do {
            pendingInvites = try await householdService.fetchPendingInvites(householdId: hid)
        } catch {
            pendingInvites = []
        }

        isLoading = false
        lastLoadedAt = .now
    }

    func toggleRole(_ member: AppUser) async {
        let newRole: UserRole = member.role == .admin ? .member : .admin
        do {
            try await householdService.updateMemberRole(userId: member.userId, role: newRole)
            await loadData()
            ToastManager.shared.show("\(member.name) is now \(newRole.rawValue)", style: .success)
        } catch {
            ToastManager.shared.show("Failed to update role", style: .error)
        }
    }

    func removeMember(_ member: AppUser) async {
        do {
            try await householdService.removeMember(userId: member.userId)
            await loadData()
            ToastManager.shared.show("\(member.name) removed", style: .success)
        } catch {
            ToastManager.shared.show("Failed to remove member", style: .error)
        }
    }

    func inviteMember(email: String) async {
        guard let user = authService.currentUser, let hid = user.householdId else { return }
        do {
            try await householdService.inviteMember(email: email, householdId: hid, invitedBy: user.userId)
            await loadData(forceRefresh: true)

            shareInviteItem = InviteShareItem(
                email: email,
                householdName: householdName,
                inviterName: user.name
            )
        } catch {
            ToastManager.shared.show(error.localizedDescription, style: .error)
        }
    }

    func cancelInvite(_ invite: HouseholdInvite) async {
        do {
            try await householdService.cancelInvite(inviteId: invite.inviteId)
            pendingInvites.removeAll { $0.inviteId == invite.inviteId }
            ToastManager.shared.show("Invite cancelled", style: .success)
        } catch {
            ToastManager.shared.show("Failed to cancel invite", style: .error)
        }
    }

    func prepareEdit() {
        editName = currentUser?.name ?? ""
        editHouseholdName = householdName
        showEditProfile = true
    }

    func saveProfile() async {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHousehold = editHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if !trimmedName.isEmpty, trimmedName != currentUser?.name {
                try await authService.updateUserName(trimmedName)
                currentUser = authService.currentUser
            }

            if let hid = currentUser?.householdId,
               !trimmedHousehold.isEmpty,
               trimmedHousehold != householdName {
                try await householdService.updateHouseholdName(id: hid, name: trimmedHousehold)
                householdName = trimmedHousehold
            }

            ToastManager.shared.show("Profile updated", style: .success)
        } catch {
            ToastManager.shared.show("Failed to update profile", style: .error)
        }
    }

    func saveNotificationPreferences() {
        UserDefaults.standard.set(expiryReminders, forKey: "expiryReminders")
        UserDefaults.standard.set(lowStockReminders, forKey: "lowStockReminders")
        ToastManager.shared.show("Preferences saved", style: .success)
    }

    func signOut() async {
        await authService.signOut()
    }

    func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch {
            ToastManager.shared.show("Failed to delete account: \(error.localizedDescription)", style: .error)
        }
    }

}

// MARK: - Invite Share Item

struct InviteShareItem: Identifiable {
    let id = UUID()
    let email: String
    let householdName: String
    let inviterName: String

    var subject: String {
        "\(inviterName) invited you to join \(householdName) on FoodPan"
    }

    var body: String {
        """
        Hi there!

        \(inviterName) has invited you to join the "\(householdName)" household on FoodPan — a smart pantry and grocery app that helps families reduce food waste and stay organized.

        To get started:
        1. Download FoodPan from the App Store
        2. Sign up with this email address: \(email)
        3. You'll automatically see the invite to join \(householdName)

        See you in the kitchen!
        """
    }
}
