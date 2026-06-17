import Foundation

/// Request body for the `send-household-invite` Edge Function.
struct HouseholdInviteEmailPayload: Encodable, Equatable, Sendable {
    let inviteId: String

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
    }
}

/// Response from the `send-household-invite` Edge Function (2xx JSON body).
struct SendHouseholdInviteAPIResponse: Decodable, Equatable, Sendable {
    let ok: Bool?
    /// When `resend_onboarding`, mail was queued via Resend using the default test `from`; recipients often do not get it until `HOUSEHOLD_INVITE_EMAIL_FROM` uses your verified domain.
    let inviteEmailSender: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case inviteEmailSender = "invite_email_sender"
    }

    var usesResendOnboardingSender: Bool {
        inviteEmailSender == "resend_onboarding"
    }
}
