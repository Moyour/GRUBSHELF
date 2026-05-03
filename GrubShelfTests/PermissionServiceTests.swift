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

    @Test func memberCannotDeleteHousehold() {
        #expect(!PermissionService.canPerform(.deleteHousehold, role: .member))
    }

    @Test func memberCannotChangeRoles() {
        #expect(!PermissionService.canPerform(.changeRoles, role: .member))
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

    @Test func adminCanDeleteHousehold() {
        #expect(PermissionService.canPerform(.deleteHousehold, role: .admin))
    }

    @Test func adminCanChangeRoles() {
        #expect(PermissionService.canPerform(.changeRoles, role: .admin))
    }
}
