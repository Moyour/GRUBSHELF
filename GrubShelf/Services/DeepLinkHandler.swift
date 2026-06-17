import Foundation
import os

/// Handles deep links for the GrubShelf app.
final class DeepLinkHandler {
    private static let logger = Logger(subsystem: "com.grubshelf", category: "DeepLink")

    enum DeepLink {
        case invite(token: UUID)
        case pantry(destination: NotificationDestination)
        case shopping
        case approvals
        case unknown
    }

    /// Parses a URL and returns the appropriate deep link action.
    /// - Parameter url: The URL to parse (e.g., grubshelf://invite?token=...)
    /// - Returns: A DeepLink enum representing the action to take
    static func parse(_ url: URL) -> DeepLink {
        logger.info("Parsing deep link: \(url.absoluteString, privacy: .public)")

        guard url.scheme == "grubshelf" else {
            logger.warning("Invalid scheme: \(url.scheme ?? "nil", privacy: .public)")
            return .unknown
        }

        let host = url.host ?? ""

        // Handle grubshelf://invite?token=<uuid>
        if host == "invite" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let tokenString = components.queryItems?.first(where: { $0.name == "token" })?.value,
                  let token = UUID(uuidString: tokenString) else {
                logger.warning("Invalid invite token in URL: \(url.absoluteString, privacy: .public)")
                return .unknown
            }

            logger.info("Parsed invite token: \(token.uuidString, privacy: .public)")
            return .invite(token: token)
        }

        // Handle grubshelf://pantry?filter=expiring|lowstock|review
        if host == "pantry" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let filter = components?.queryItems?.first(where: { $0.name == "filter" })?.value
            let destination: NotificationDestination
            switch filter {
            case "expiring":  destination = .pantryExpiring
            case "lowstock":  destination = .pantryLowStock
            case "review":    destination = .pantryReview
            default:          destination = .pantryExpiring
            }
            logger.info("Parsed pantry deep link with filter: \(filter ?? "default", privacy: .public)")
            return .pantry(destination: destination)
        }

        // Handle grubshelf://shop
        if host == "shop" {
            logger.info("Parsed shopping deep link")
            return .shopping
        }

        // Handle grubshelf://approvals
        if host == "approvals" {
            logger.info("Parsed approvals deep link")
            return .approvals
        }

        logger.warning("Unknown deep link host: \(host, privacy: .public)")
        return .unknown
    }
}
