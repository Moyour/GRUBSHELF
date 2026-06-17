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
    var pendingShareInvite: HouseholdInvite?
    var editName = ""
    var editHouseholdName = ""

    /// True while `saveProfile` is running.
    private(set) var isSavingProfile = false
    /// True while `inviteMember` is running.
    private(set) var isInvitingMember = false
    /// Member IDs whose role is currently being toggled or who are being removed.
    private(set) var inflightMemberIds: Set<UUID> = []
    /// Invite IDs currently being cancelled.
    private(set) var inflightInviteIds: Set<UUID> = []

    private let authService: AuthenticationService
    private let householdService: HouseholdService
    /// Optional gate service for enforcing subscription limits on member invites.
    @ObservationIgnored var featureGateService: FeatureGateService?
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
        // Use the captured `hid` for the rest of this refresh so a transient
        // server result that returns a household-less profile cannot cause us
        // to skip household/member fetches or flip the routing back to
        // CreateHouseholdView. The auth service merge guard normally protects
        // currentUser too; this is the local belt-and-braces guarantee.
        currentUser = authService.currentUser ?? user
        emailNotificationsEnabled = currentUser?.emailNotificationsEnabled ?? true

        do {
            // Check for cancellation before starting expensive operations
            try Task.checkCancellation()
            
            async let householdFetch = householdService.fetchHousehold(id: hid)
            async let membersFetch = householdService.fetchMembers(householdId: hid)
            let (household, fetchedMembers) = try await (householdFetch, membersFetch)
            householdName = household.name
            members = fetchedMembers
        } catch is CancellationError {
            // Task was cancelled (e.g., view was dismissed) — silently ignore
            Self.logger.info("loadData cancelled gracefully")
            isLoading = false
            return
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
            try Task.checkCancellation()
            pendingInvites = try await householdService.fetchPendingInvites(householdId: hid)
        } catch is CancellationError {
            Self.logger.info("loadData invite fetch cancelled gracefully")
        } catch {
            pendingInvites = []
        }

        isLoading = false
        lastLoadedAt = .now
    }

    func toggleRole(_ member: AppUser) async {
        guard inflightMemberIds.insert(member.userId).inserted else { return }
        defer { inflightMemberIds.remove(member.userId) }
        let newRole: UserRole = member.role == .admin ? .member : .admin
        do {
            try await householdService.updateMemberRole(userId: member.userId, role: newRole)
            await loadData()
            ToastManager.shared.show("\(member.name) is now \(newRole.rawValue)", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "update role"),
                style: .error
            )
        }
    }

    func removeMember(_ member: AppUser) async {
        guard inflightMemberIds.insert(member.userId).inserted else { return }
        defer { inflightMemberIds.remove(member.userId) }
        do {
            try await householdService.removeMember(userId: member.userId)
            await loadData()
            ToastManager.shared.show("\(member.name) removed", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "remove member"),
                style: .error
            )
        }
    }

    var canInviteMembers: Bool {
        guard let user = authService.currentUser else { return false }
        return PermissionService.canPerform(.manageMembers, context: HouseholdPermissionContext(user: user))
    }

    func inviteMember(email: String) async {
        guard !isInvitingMember else { return }
        isInvitingMember = true
        defer { isInvitingMember = false }
        guard let user = authService.currentUser, let hid = user.householdId else {
            showInviteSheet = false
            return
        }
        // Check household member limit
        if let gate = featureGateService {
            let allowed = await gate.checkLimit(.householdMembers, householdId: hid)
            if !allowed {
                showInviteSheet = false
                return
            }
        }
        guard PermissionService.canPerform(.manageMembers, context: HouseholdPermissionContext(user: user)) else {
            showInviteSheet = false
            ToastManager.shared.show("Only household admins can invite members.", style: .error)
            return
        }
        do {
            let result = try await householdService.inviteMember(email: email, householdId: hid, invitedBy: user.userId)
            showInviteSheet = false
            try? await Task.sleep(for: .milliseconds(400))
            pendingShareInvite = result.invite
            if result.emailDelivered {
                if result.usedResendOnboardingSender {
                    ToastManager.shared.show(
                        "Invite saved. Email used Resend’s test sender—many inboxes never receive it. Verify a domain in Resend and set HOUSEHOLD_INVITE_EMAIL_FROM on send-household-invite. They can still join in the app with \(email).",
                        style: .warning,
                        duration: 10
                    )
                } else {
                    ToastManager.shared.show("Invite sent to \(email)", style: .success, duration: 5)
                }
            } else {
                ToastManager.shared.show(
                    "Invite created, but the email could not be sent. \(email) can still accept it from the app.",
                    style: .warning,
                    duration: 6
                )
            }
            await loadData(forceRefresh: true)
        } catch {
            showInviteSheet = false
            try? await Task.sleep(for: .milliseconds(400))
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "invite member"),
                style: .error
            )
        }
    }

    func cancelInvite(_ invite: HouseholdInvite) async {
        guard inflightInviteIds.insert(invite.inviteId).inserted else { return }
        defer { inflightInviteIds.remove(invite.inviteId) }
        do {
            try await householdService.cancelInvite(inviteId: invite.inviteId)
            await loadData(forceRefresh: true)
            ToastManager.shared.show("Invite cancelled", style: .success)
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "cancel invite"),
                style: .error
            )
        }
    }

    func prepareEdit() {
        editName = currentUser?.name ?? ""
        editHouseholdName = householdName
        showEditProfile = true
    }

    func saveProfile() async {
        guard !isSavingProfile else { return }
        isSavingProfile = true
        defer { isSavingProfile = false }
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
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "update profile"),
                style: .error
            )
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
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "update email preference"),
                style: .error
            )
        }
    }

    func saveNotificationPreferences() {
        UserDefaults.standard.set(expiryReminders, forKey: "expiryReminders")
        UserDefaults.standard.set(lowStockReminders, forKey: "lowStockReminders")
        ToastManager.shared.show("Preferences saved", style: .success)
    }

    func inviteShareItems(for invite: HouseholdInvite) -> [Any] {
        let deepLink = "grubshelf://invite?token=\(invite.inviteId.uuidString)"
        let message = "Join my household on GrubShelf! Tap to accept: \(deepLink)\n\nDon't have the app yet? Download it from TestFlight."
        return [message as Any]
    }

    func signOut() async {
        await authService.signOut()
    }

    func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch {
            ToastManager.shared.show(
                ErrorHandler.userMessage(for: error, action: "delete account"),
                style: .error
            )
        }
    }

}
