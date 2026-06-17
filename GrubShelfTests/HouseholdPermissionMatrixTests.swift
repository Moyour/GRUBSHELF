import Testing
@testable import GrubShelf

/// Mirrors server-side permission matrix from docs/PERMISSIONS.md for client UI gating.
struct HouseholdPermissionMatrixTests {
    private func ownerContext() -> HouseholdPermissionContext {
        HouseholdPermissionContext(role: .admin, isOwner: true, canModifyBudget: true)
    }

    private func adminContext() -> HouseholdPermissionContext {
        HouseholdPermissionContext(role: .admin, isOwner: false, canModifyBudget: true)
    }

    private func memberContext() -> HouseholdPermissionContext {
        HouseholdPermissionContext(role: .member, isOwner: false, canModifyBudget: false)
    }

    private func guestContext() -> HouseholdPermissionContext {
        HouseholdPermissionContext(role: .guest, isOwner: false, canModifyBudget: false)
    }

    @Test func ownerHasFullGovernancePermissions() {
        let ctx = ownerContext()
        #expect(PermissionService.canPerform(.deleteHousehold, context: ctx))
        #expect(PermissionService.canPerform(.changeRoles, context: ctx))
        #expect(PermissionService.canPerform(.manageMembers, context: ctx))
        #expect(PermissionService.canPerform(.approveItems, context: ctx))
    }

    @Test func adminLacksGovernanceButCanOperate() {
        let ctx = adminContext()
        #expect(!PermissionService.canPerform(.deleteHousehold, context: ctx))
        #expect(!PermissionService.canPerform(.changeRoles, context: ctx))
        #expect(PermissionService.canPerform(.manageMembers, context: ctx))
        #expect(PermissionService.canPerform(.approveItems, context: ctx))
        #expect(PermissionService.canPerform(.deleteItem, context: ctx))
    }

    @Test func memberIsContributorOnly() {
        let ctx = memberContext()
        #expect(PermissionService.canPerform(.addItem, context: ctx))
        #expect(!PermissionService.canPerform(.deleteItem, context: ctx))
        #expect(!PermissionService.canPerform(.approveItems, context: ctx))
        #expect(!PermissionService.canPerform(.modifyBudget, context: ctx))
        #expect(!PermissionService.canPerform(.manageMembers, context: ctx))
        #expect(!PermissionService.canPerform(.createShoppingList, context: ctx))
        #expect(!PermissionService.canPerform(.deleteShoppingList, context: ctx))
    }

    @Test func adminCanInviteAndCreateLists() {
        let ctx = adminContext()
        #expect(PermissionService.canPerform(.manageMembers, context: ctx))
        #expect(PermissionService.canPerform(.createShoppingList, context: ctx))
        #expect(PermissionService.canPerform(.deleteShoppingList, context: ctx))
        #expect(PermissionService.canPerform(.modifyBudget, context: ctx))
    }

    @Test func guestIsReadOnlyClientSide() {
        let ctx = guestContext()
        #expect(!PermissionService.canPerform(.addItem, context: ctx))
        #expect(!PermissionService.canPerform(.editItem, context: ctx))
        #expect(!PermissionService.canPerform(.deleteItem, context: ctx))
        #expect(!PermissionService.canPerform(.approveItems, context: ctx))
    }
}
