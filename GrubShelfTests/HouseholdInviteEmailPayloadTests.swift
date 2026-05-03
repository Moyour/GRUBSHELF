import Foundation
import Testing
@testable import GrubShelf

struct HouseholdInviteEmailPayloadTests {
    @Test func encodesInviteIdSnakeCaseForEdgeFunction() throws {
        let payload = HouseholdInviteEmailPayload(inviteId: "550e8400-e29b-41d4-a716-446655440000")
        let data = try JSONEncoder().encode(payload)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(obj["invite_id"] == "550e8400-e29b-41d4-a716-446655440000")
        #expect(obj.count == 1)
    }
}
