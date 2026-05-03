import Foundation

struct ShoppingList: Codable, Identifiable, Equatable, Hashable, Sendable {
    let listId: UUID
    let householdId: UUID
    var name: String
    let createdBy: UUID
    let createdAt: Date
    var updatedAt: Date
    var transferred: Bool

    var id: UUID { listId }

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case householdId = "household_id"
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case transferred
    }

    init(listId: UUID, householdId: UUID, name: String, createdBy: UUID, createdAt: Date, updatedAt: Date, transferred: Bool) {
        self.listId = listId
        self.householdId = householdId
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transferred = transferred
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listId = try container.decode(UUID.self, forKey: .listId)
        householdId = try container.decode(UUID.self, forKey: .householdId)
        name = try container.decode(String.self, forKey: .name)
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        transferred = try container.decodeIfPresent(Bool.self, forKey: .transferred) ?? false
    }
}
