import Foundation
import Testing
@testable import GrubShelf

struct DeepLinkHandlerTests {
    private let token = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

    @Test func parseInviteLink() {
        let url = URL(string: "grubshelf://invite?token=\(token.uuidString)")!
        let link = DeepLinkHandler.parse(url)
        guard case .invite(let parsed) = link else {
            Issue.record("Expected invite deep link")
            return
        }
        #expect(parsed == token)
    }

    @Test func parseRejectsWrongScheme() {
        let url = URL(string: "https://example.com/invite?token=\(token.uuidString)")!
        if case .unknown = DeepLinkHandler.parse(url) { } else {
            Issue.record("Expected unknown deep link")
        }
    }

    @Test func parseRejectsInvalidToken() {
        let url = URL(string: "grubshelf://invite?token=not-a-uuid")!
        if case .unknown = DeepLinkHandler.parse(url) { } else {
            Issue.record("Expected unknown deep link")
        }
    }

    @Test func parseRejectsUnknownHost() {
        let url = URL(string: "grubshelf://settings")!
        if case .unknown = DeepLinkHandler.parse(url) { } else {
            Issue.record("Expected unknown deep link")
        }
    }

    // MARK: - Pantry deep links

    @Test func parsePantryExpiring() {
        let url = URL(string: "grubshelf://pantry?filter=expiring")!
        guard case .pantry(let dest) = DeepLinkHandler.parse(url) else {
            Issue.record("Expected pantry deep link")
            return
        }
        #expect(dest == .pantryExpiring)
    }

    @Test func parsePantryLowStock() {
        let url = URL(string: "grubshelf://pantry?filter=lowstock")!
        guard case .pantry(let dest) = DeepLinkHandler.parse(url) else {
            Issue.record("Expected pantry deep link")
            return
        }
        #expect(dest == .pantryLowStock)
    }

    @Test func parsePantryReview() {
        let url = URL(string: "grubshelf://pantry?filter=review")!
        guard case .pantry(let dest) = DeepLinkHandler.parse(url) else {
            Issue.record("Expected pantry deep link")
            return
        }
        #expect(dest == .pantryReview)
    }

    @Test func parsePantryNoFilterDefaultsToExpiring() {
        let url = URL(string: "grubshelf://pantry")!
        guard case .pantry(let dest) = DeepLinkHandler.parse(url) else {
            Issue.record("Expected pantry deep link")
            return
        }
        #expect(dest == .pantryExpiring)
    }

    // MARK: - Shopping deep link

    @Test func parseShoppingLink() {
        let url = URL(string: "grubshelf://shop")!
        if case .shopping = DeepLinkHandler.parse(url) { } else {
            Issue.record("Expected shopping deep link")
        }
    }

    // MARK: - Approvals deep link

    @Test func parseApprovalsLink() {
        let url = URL(string: "grubshelf://approvals")!
        if case .approvals = DeepLinkHandler.parse(url) { } else {
            Issue.record("Expected approvals deep link")
        }
    }

    @Test func parsePantryUnknownFilterDefaultsToExpiring() {
        let url = URL(string: "grubshelf://pantry?filter=bogus")!
        guard case .pantry(let dest) = DeepLinkHandler.parse(url) else {
            Issue.record("Expected pantry deep link")
            return
        }
        #expect(dest == .pantryExpiring)
    }
}
