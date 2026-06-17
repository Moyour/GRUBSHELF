import Foundation
import Testing
@testable import GrubShelf

struct PermissionServiceTests {
    // MARK: - Member permissions

    @Test func memberCanAddItem() {
        #expect(PermissionService.canPerform(.addItem, role: .member))
    }

    @Test func memberCanEditItem() {
        #expect(PermissionService.canPerform(.editItem, role: .member))
    }

    @Test func memberCannotDeleteItem() {
        #expect(!PermissionService.canPerform(.deleteItem, role: .member))
    }

    @Test func memberCannotManageMembers() {
        #expect(!PermissionService.canPerform(.manageMembers, role: .member))
    }

    @Test func memberCannotCreateShoppingList() {
        #expect(!PermissionService.canPerform(.createShoppingList, role: .member))
    }

    @Test func adminCanCreateShoppingList() {
        #expect(PermissionService.canPerform(.createShoppingList, role: .admin))
    }

    @Test func memberCannotDeleteShoppingList() {
        #expect(!PermissionService.canPerform(.deleteShoppingList, role: .member))
    }

    @Test func adminCanDeleteShoppingList() {
        #expect(PermissionService.canPerform(.deleteShoppingList, role: .admin))
    }

    @Test func memberCannotDeleteHousehold() {
        #expect(!PermissionService.canPerform(.deleteHousehold, role: .member))
    }

    @Test func memberCannotChangeRoles() {
        #expect(!PermissionService.canPerform(.changeRoles, role: .member))
    }

    @Test func memberCannotApproveItems() {
        #expect(!PermissionService.canPerform(.approveItems, role: .member))
    }

    // MARK: - Admin permissions

    @Test func adminCanAddItem() {
        #expect(PermissionService.canPerform(.addItem, role: .admin))
    }

    @Test func adminCanDeleteItem() {
        #expect(PermissionService.canPerform(.deleteItem, role: .admin))
    }

    @Test func adminCanManageMembers() {
        #expect(PermissionService.canPerform(.manageMembers, role: .admin))
    }

    @Test func adminCannotDeleteHouseholdWithoutOwnerFlag() {
        #expect(!PermissionService.canPerform(.deleteHousehold, role: .admin))
    }

    @Test func adminCannotChangeRolesWithoutOwnerFlag() {
        #expect(!PermissionService.canPerform(.changeRoles, role: .admin))
    }

    @Test func adminCanApproveItems() {
        #expect(PermissionService.canPerform(.approveItems, role: .admin))
    }

    @Test func adminCanModifyBudgetByDefault() {
        let context = HouseholdPermissionContext(role: .admin, isOwner: false, canModifyBudget: true)
        #expect(PermissionService.canPerform(.modifyBudget, context: context))
    }

    // MARK: - Owner permissions

    @Test func ownerCanDeleteHousehold() {
        #expect(PermissionService.canPerform(.deleteHousehold, role: .admin, isOwner: true))
    }

    @Test func ownerCanChangeRoles() {
        #expect(PermissionService.canPerform(.changeRoles, role: .admin, isOwner: true))
    }

    @Test func ownerCanManageMembers() {
        #expect(PermissionService.canPerform(.manageMembers, role: .admin, isOwner: true))
    }

    // MARK: - Guest permissions

    @Test func guestCannotAddOrEditItems() {
        #expect(!PermissionService.canPerform(.addItem, role: .guest))
        #expect(!PermissionService.canPerform(.editItem, role: .guest))
    }

    @Test func guestCannotManageHousehold() {
        #expect(!PermissionService.canPerform(.manageMembers, role: .guest))
        #expect(!PermissionService.canPerform(.deleteHousehold, role: .guest))
        #expect(!PermissionService.canPerform(.changeRoles, role: .guest))
    }

    // MARK: - AppUser context

    @Test func appUserOwnerContext() {
        let owner = AppUser(
            userId: UUID(),
            name: "Owner",
            email: "owner@test.com",
            householdId: UUID(),
            role: .admin,
            isOwner: true,
            createdAt: .now,
            updatedAt: .now
        )
        let context = HouseholdPermissionContext(user: owner)
        #expect(PermissionService.canPerform(.deleteHousehold, context: context))
        #expect(PermissionService.canPerform(.changeRoles, context: context))
    }

    @Test func secondaryAdminCannotDeleteHousehold() {
        let admin = AppUser(
            userId: UUID(),
            name: "Admin",
            email: "admin@test.com",
            householdId: UUID(),
            role: .admin,
            isOwner: false,
            createdAt: .now,
            updatedAt: .now
        )
        let context = HouseholdPermissionContext(user: admin)
        #expect(!PermissionService.canPerform(.deleteHousehold, context: context))
        #expect(PermissionService.canPerform(.approveItems, context: context))
    }
}
