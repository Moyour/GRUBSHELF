import Foundation
import Testing
@testable import GrubShelf

struct MemberRoleLabelTests {
    private func makeUser(role: UserRole, isOwner: Bool = false) -> AppUser {
        AppUser(
            userId: UUID(),
            name: "Test",
            email: "test@example.com",
            householdId: UUID(),
            role: role,
            isOwner: isOwner,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func guestLabel() {
        #expect(MemberRoleLabel.display(for: makeUser(role: .guest)) == "Guest")
    }

    @Test func memberLabel() {
        #expect(MemberRoleLabel.display(for: makeUser(role: .member)) == "Member")
    }

    @Test func adminLabel() {
        #expect(MemberRoleLabel.display(for: makeUser(role: .admin)) == "Admin")
    }

    @Test func ownerLabelTakesPrecedence() {
        #expect(MemberRoleLabel.display(for: makeUser(role: .admin, isOwner: true)) == "Owner")
    }
}
