import Foundation

enum PermissionAction {
    case addItem
    case editItem
    case deleteItem
    case manageMembers
    case deleteHousehold
    case changeRoles
}

struct PermissionService {
    static func canPerform(_ action: PermissionAction, role: UserRole) -> Bool {
        switch action {
        case .addItem, .editItem:
            return true
        case .deleteItem, .manageMembers, .deleteHousehold, .changeRoles:
            return role == .admin
        }
    }
}
