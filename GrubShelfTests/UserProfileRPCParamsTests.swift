import Foundation
import Testing
@testable import GrubShelf

struct UserProfileRPCParamsTests {
    @Test func ensureUserProfileParams_hasExpectedKeysAndNoRole() {
        let uid = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let hid = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let params = UserProfileRPC.ensureUserProfileParams(
            userId: uid,
            name: "Pat",
            email: "pat@example.com",
            householdId: hid
        )

        #expect(params["p_user_id"] == uid.uuidString)
        #expect(params["p_name"] == "Pat")
        #expect(params["p_email"] == "pat@example.com")
        #expect(params["p_household_id"] == hid.uuidString)
        #expect(params["p_role"] == nil)
        #expect(params.count == 4)
    }

    @Test func rpcFunctionNames_matchSupabase() {
        #expect(UserProfileRPC.ensureUserProfileFunctionName == "ensure_user_profile")
        #expect(UserProfileRPC.setSelfAdminForHouseholdFunctionName == "set_self_admin_for_household")
    }
}
