import Foundation

enum PermissionAction {
    case addItem
    case editItem
    case deleteItem
    case manageMembers
    case deleteHousehold
    case changeRoles
    case approveItems
    case modifyBudget
    case createShoppingList
    case deleteShoppingList
}

struct HouseholdPermissionContext: Equatable, Sendable {
    let role: UserRole
    let isOwner: Bool
    let canModifyBudget: Bool

    init(role: UserRole, isOwner: Bool = false, canModifyBudget: Bool = false) {
        self.role = role
        self.isOwner = isOwner
        self.canModifyBudget = canModifyBudget
    }

    init(user: AppUser) {
        self.role = user.role
        self.isOwner = user.isOwner
        self.canModifyBudget = user.role == .admin || user.isOwner
    }
}

struct PermissionService {
    static func canPerform(_ action: PermissionAction, role: UserRole, isOwner: Bool = false) -> Bool {
        canPerform(action, context: HouseholdPermissionContext(role: role, isOwner: isOwner))
    }

    static func canPerform(_ action: PermissionAction, context: HouseholdPermissionContext) -> Bool {
        switch action {
        case .addItem, .editItem:
            return context.role != .guest
        case .deleteItem, .approveItems:
            return context.role == .admin || context.isOwner
        case .manageMembers:
            return context.role == .admin || context.isOwner
        case .deleteHousehold, .changeRoles:
            return context.isOwner
        case .modifyBudget:
            return context.canModifyBudget || context.role == .admin || context.isOwner
        case .createShoppingList, .deleteShoppingList:
            return context.role == .admin || context.isOwner
        }
    }
}
