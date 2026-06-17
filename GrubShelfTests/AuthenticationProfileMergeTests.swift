import Foundation
import Testing
@testable import GrubShelf

/// Regression tests for `AuthenticationService.mergeReloadedProfile`.
///
/// The merge guard exists to prevent pull-to-refresh on the Home tab from
/// dropping a household-linked user back to `CreateHouseholdView` when the
/// `users` row briefly comes back with `household_id == NULL` (e.g. transient
/// RLS/timing issue right after a session refresh).
struct AuthenticationProfileMergeTests {
    private static let userId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private static let otherUserId = UUID(uuidString: "00000000-0000-4000-8000-0000000000FF")!
    private static let householdId = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
    private static let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let updatedAt = Date(timeIntervalSince1970: 1_700_000_100)

    private static func makeUser(
        userId: UUID = AuthenticationProfileMergeTests.userId,
        name: String = "Pat",
        email: String = "pat@example.com",
        householdId: UUID? = nil,
        role: UserRole = .member,
        isOwner: Bool = false
    ) -> AppUser {
        AppUser(
            userId: userId,
            name: name,
            email: email,
            householdId: householdId,
            role: role,
            isOwner: isOwner,
            emailNotificationsEnabled: true,
            createdAt: AuthenticationProfileMergeTests.createdAt,
            updatedAt: AuthenticationProfileMergeTests.updatedAt
        )
    }

    @Test func preservesExistingHouseholdWhenReloadDropsIt() {
        let existing = Self.makeUser(householdId: Self.householdId, role: .admin, isOwner: true)
        let reloaded = Self.makeUser(householdId: nil, role: .member, isOwner: false)

        let merged = AuthenticationService.mergeReloadedProfile(existing: existing, reloaded: reloaded)

        #expect(merged.householdId == Self.householdId)
        #expect(merged.role == .admin)
        #expect(merged.isOwner == true)
    }

    @Test func usesReloadedProfileWhenBothHaveHousehold() {
        let existing = Self.makeUser(householdId: Self.householdId, role: .member)
        let reloadedHousehold = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let reloaded = Self.makeUser(
            name: "Pat (renamed)",
            householdId: reloadedHousehold,
            role: .admin,
            isOwner: true
        )

        let merged = AuthenticationService.mergeReloadedProfile(existing: existing, reloaded: reloaded)

        #expect(merged.householdId == reloadedHousehold)
        #expect(merged.name == "Pat (renamed)")
        #expect(merged.role == .admin)
        #expect(merged.isOwner == true)
    }

    @Test func returnsReloadedUnchangedWhenExistingHasNoHousehold() {
        // Brand-new user scenario: existing has no household, reload also has
        // none. Onboarding must continue, not be short-circuited.
        let existing = Self.makeUser(householdId: nil)
        let reloaded = Self.makeUser(householdId: nil)

        let merged = AuthenticationService.mergeReloadedProfile(existing: existing, reloaded: reloaded)

        #expect(merged.householdId == nil)
    }

    @Test func returnsReloadedUnchangedWhenExistingIsNil() {
        // First-load case (e.g. checkSession after launch).
        let reloaded = Self.makeUser(householdId: Self.householdId)

        let merged = AuthenticationService.mergeReloadedProfile(existing: nil, reloaded: reloaded)

        #expect(merged.householdId == Self.householdId)
        #expect(merged.userId == reloaded.userId)
    }

    @Test func returnsReloadedUnchangedWhenUserIdsDiffer() {
        // Defensive: never blend household membership across different users.
        let existing = Self.makeUser(userId: Self.userId, householdId: Self.householdId)
        let reloaded = Self.makeUser(userId: Self.otherUserId, householdId: nil)

        let merged = AuthenticationService.mergeReloadedProfile(existing: existing, reloaded: reloaded)

        #expect(merged.householdId == nil)
        #expect(merged.userId == Self.otherUserId)
    }

    @Test func usesReloadedHouseholdWhenExistingHadNone() {
        // Successful onboarding completion: previously household-less user now
        // has a household after creating or joining one.
        let existing = Self.makeUser(householdId: nil)
        let reloaded = Self.makeUser(householdId: Self.householdId, role: .admin, isOwner: true)

        let merged = AuthenticationService.mergeReloadedProfile(existing: existing, reloaded: reloaded)

        #expect(merged.householdId == Self.householdId)
        #expect(merged.role == .admin)
        #expect(merged.isOwner == true)
    }
}
