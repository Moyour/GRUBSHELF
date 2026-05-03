import Foundation
import Observation
import os

@MainActor
@Observable
final class ProfileViewModel {
    var currentUser: AppUser?
    var householdName = ""
    var members: [AppUser] = []
    var pendingInvites: [HouseholdInvite] = []
    var expiryReminders = true
    var lowStockReminders = true
    var emailNotificationsEnabled = true
    var isLoading = false
    var showDeleteConfirmation = false
    var showInviteSheet = false
    var showEditProfile = false
    var editName = ""
    var editHouseholdName = ""
    private let authService: AuthenticationService
    private let householdService: HouseholdService
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 30
    private static let logger = Logger(subsystem: "com.grubshelf", category: "Profile")

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

        await authService.reloadUserProfileFromServer()
        currentUser = authService.currentUser
        emailNotificationsEnabled = currentUser?.emailNotificationsEnabled ?? true

        do {
            async let householdFetch = householdService.fetchHousehold(id: hid)
            async let membersFetch = householdService.fetchMembers(householdId: hid)
            let (household, fetchedMembers) = try await (householdFetch, membersFetch)
            householdName = household.name
            members = fetchedMembers
        } catch {
            Self.logger.error("loadData failed: \(error.localizedDescription, privacy: .public)")
            let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = detail.isEmpty
                ? "Failed to load profile"
                : "Failed to load profile — \(detail)"
            ToastManager.shared.show(message, style: .error)
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
            _ = try await householdService.inviteMember(email: email, householdId: hid, invitedBy: user.userId)
            showInviteSheet = false
            try? await Task.sleep(for: .milliseconds(400))
            ToastManager.shared.show("Invite sent to \(email)", style: .success)
            await loadData(forceRefresh: true)
        } catch {
            ToastManager.shared.show(error.localizedDescription, style: .error)
        }
    }

    func cancelInvite(_ invite: HouseholdInvite) async {
        do {
            try await householdService.cancelInvite(inviteId: invite.inviteId)
            await loadData(forceRefresh: true)
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

    func saveEmailNotificationPreference() async {
        guard let user = authService.currentUser else { return }
        do {
            try await SupabaseManager.shared.client.from("users")
                .update(["email_notifications_enabled": emailNotificationsEnabled])
                .eq("user_id", value: user.userId.uuidString)
                .execute()
        } catch {
            ToastManager.shared.show("Failed to update email preference", style: .error)
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
