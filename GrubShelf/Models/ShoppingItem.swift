import Foundation

struct ShoppingItem: Codable, Identifiable, Equatable, Sendable {
    let itemId: UUID
    let householdId: UUID
    var listId: UUID?
    var name: String
    var quantity: Double
    var unit: UnitType?
    var category: String?
    var completed: Bool
    var transferred: Bool
    let createdBy: UUID
    let createdAt: Date
    var updatedAt: Date
    var approvalStatus: ApprovalStatus
    var approvedBy: UUID?
    var approvedAt: Date?
    var rejectionReason: String?
    /// Canonical grocery catalog product id (each catalog row has a unique UUID).
    var catalogItemId: UUID?

    var id: UUID { itemId }

    var isApproved: Bool { approvalStatus == .approved }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case householdId = "household_id"
        case listId = "list_id"
        case name, quantity, unit, category, completed, transferred
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case approvalStatus = "approval_status"
        case approvedBy = "approved_by"
        case approvedAt = "approved_at"
        case rejectionReason = "rejection_reason"
        case catalogItemId = "catalog_item_id"
    }

    init(
        itemId: UUID,
        householdId: UUID,
        listId: UUID?,
        name: String,
        quantity: Double,
        unit: UnitType?,
        category: String?,
        completed: Bool,
        transferred: Bool = false,
        createdBy: UUID,
        createdAt: Date,
        updatedAt: Date,
        approvalStatus: ApprovalStatus = .approved,
        approvedBy: UUID? = nil,
        approvedAt: Date? = nil,
        rejectionReason: String? = nil,
        catalogItemId: UUID? = nil
    ) {
        self.itemId = itemId
        self.householdId = householdId
        self.listId = listId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.completed = completed
        self.transferred = transferred
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.approvalStatus = approvalStatus
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.rejectionReason = rejectionReason
        self.catalogItemId = catalogItemId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try container.decode(UUID.self, forKey: .itemId)
        householdId = try container.decode(UUID.self, forKey: .householdId)
        listId = try container.decodeIfPresent(UUID.self, forKey: .listId)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decodeIfPresent(UnitType.self, forKey: .unit)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        completed = try container.decode(Bool.self, forKey: .completed)
        transferred = try container.decodeIfPresent(Bool.self, forKey: .transferred) ?? false
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        approvalStatus = try container.decodeIfPresent(ApprovalStatus.self, forKey: .approvalStatus) ?? .approved
        approvedBy = try container.decodeIfPresent(UUID.self, forKey: .approvedBy)
        approvedAt = try container.decodeIfPresent(Date.self, forKey: .approvedAt)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        catalogItemId = try container.decodeIfPresent(UUID.self, forKey: .catalogItemId)
    }
}
