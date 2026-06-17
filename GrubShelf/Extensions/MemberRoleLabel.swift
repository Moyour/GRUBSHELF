import Foundation

enum MemberRoleLabel {
    static func display(for member: AppUser) -> String {
        if member.isOwner { return "Owner" }
        if member.role == .admin { return "Admin" }
        if member.role == .guest { return "Guest" }
        return "Member"
    }
}
