import Foundation

/// Request body for the `send-household-invite` Edge Function.
struct HouseholdInviteEmailPayload: Encodable, Equatable, Sendable {
    let inviteId: String

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
    }
}
