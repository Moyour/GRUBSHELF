import Foundation

enum ApprovalStatus: String, Codable, Sendable {
    case approved
    case pending
    case rejected

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ApprovalStatus(rawValue: raw) ?? .approved
    }
}
