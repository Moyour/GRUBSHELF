import Foundation
import Testing
@testable import GrubShelf

struct NotificationNavigationStoreTests {
    @Test func enqueueAndConsumeRoundTrip() {
        NotificationNavigationStore.clear()
        defer { NotificationNavigationStore.clear() }

        NotificationNavigationStore.enqueue(.approvals)
        #expect(NotificationNavigationStore.consume() == .approvals)
        #expect(NotificationNavigationStore.consume() == nil)
    }

    @Test func clearRemovesPending() {
        NotificationNavigationStore.enqueue(.shop)
        NotificationNavigationStore.clear()
        #expect(NotificationNavigationStore.consume() == nil)
    }
}
