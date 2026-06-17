import Foundation
import Testing
@testable import GrubShelf

/// Regression: dismissing one pending invite must not clear the entire queue.
@MainActor
struct PendingInviteDismissTests {
    private func makeInvite(email: String) -> HouseholdInviteWithName {
        HouseholdInviteWithName(
            inviteId: UUID(),
            householdId: UUID(),
            invitedEmail: email,
            invitedBy: UUID(),
            status: .pending,
            createdAt: .now,
            expiresAt: Date().addingTimeInterval(86400),
            households: .init(name: "Household")
        )
    }

    @Test func dismissPendingInviteRemovesOnlyOne() {
        let auth = AuthenticationService()
        let first = makeInvite(email: "a@test.com")
        let second = makeInvite(email: "b@test.com")
        auth.pendingInvitesToAccept = [first, second]

        auth.dismissPendingInvite(inviteId: first.inviteId)

        #expect(auth.pendingInvitesToAccept.count == 1)
        #expect(auth.pendingInvitesToAccept.first?.inviteId == second.inviteId)
    }
}
