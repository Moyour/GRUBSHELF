import Foundation

struct PantryItem: Codable, Identifiable, Equatable, Sendable {
    let itemId: UUID
    let householdId: UUID
    var name: String
    var quantity: Double
    var unit: UnitType
    var category: String
    var expiryDate: Date?
    var costPerUnitMinor: Int?
    var lowStockThreshold: Double
    let createdBy: UUID
    let createdAt: Date
    var updatedAt: Date
    var archived: Bool

    // Usage tracking
    var lastQuantityUpdateDate: Date?
    var expectedUsageCycleDays: Int?
    var reminderStatus: ReminderStatus
    var reminderSnoozedUntil: Date?

    var id: UUID { itemId }

    init(
        itemId: UUID,
        householdId: UUID,
        name: String,
        quantity: Double,
        unit: UnitType,
        category: String,
        expiryDate: Date? = nil,
        costPerUnitMinor: Int? = nil,
        lowStockThreshold: Double,
        createdBy: UUID,
        createdAt: Date,
        updatedAt: Date,
        archived: Bool,
        lastQuantityUpdateDate: Date? = nil,
        expectedUsageCycleDays: Int? = nil,
        reminderStatus: ReminderStatus = .active,
        reminderSnoozedUntil: Date? = nil
    ) {
        self.itemId = itemId
        self.householdId = householdId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.expiryDate = expiryDate
        self.costPerUnitMinor = costPerUnitMinor
        self.lowStockThreshold = lowStockThreshold
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
        self.lastQuantityUpdateDate = lastQuantityUpdateDate
        self.expectedUsageCycleDays = expectedUsageCycleDays
        self.reminderStatus = reminderStatus
        self.reminderSnoozedUntil = reminderSnoozedUntil
    }

    var state: ItemState {
        if archived || quantity <= 0 { return .archived }
        if let expiry = expiryDate {
            if expiry < Date.now { return .expired }
            if expiry < Date.now.addingTimeInterval(3 * 24 * 60 * 60) { return .expiringSoon }
        }
        if quantity <= lowStockThreshold { return .lowStock }
        if isStale { return .stale }
        return .active
    }

    var isStale: Bool {
        guard let cycleDays = expectedUsageCycleDays, cycleDays > 0 else { return false }
        let lastUpdate = lastQuantityUpdateDate ?? updatedAt
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdate, to: .now).day ?? 0
        return daysSinceUpdate >= cycleDays
    }

    var daysSinceLastUpdate: Int {
        let lastUpdate = lastQuantityUpdateDate ?? updatedAt
        return Calendar.current.dateComponents([.day], from: lastUpdate, to: .now).day ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case householdId = "household_id"
        case name, quantity, unit, category
        case expiryDate = "expiry_date"
        case costPerUnitMinor = "cost_per_unit_minor"
        case lowStockThreshold = "low_stock_threshold"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archived
        case lastQuantityUpdateDate = "last_quantity_update_date"
        case expectedUsageCycleDays = "expected_usage_cycle_days"
        case reminderStatus = "reminder_status"
        case reminderSnoozedUntil = "reminder_snoozed_until"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(UUID.self, forKey: .itemId)
        householdId = try c.decode(UUID.self, forKey: .householdId)
        name = try c.decode(String.self, forKey: .name)
        quantity = try c.decode(Double.self, forKey: .quantity)
        unit = try c.decode(UnitType.self, forKey: .unit)
        category = try c.decode(String.self, forKey: .category)
        expiryDate = try c.decodeIfPresent(Date.self, forKey: .expiryDate)
        costPerUnitMinor = try c.decodeIfPresent(Int.self, forKey: .costPerUnitMinor)
        lowStockThreshold = try c.decode(Double.self, forKey: .lowStockThreshold)
        createdBy = try c.decode(UUID.self, forKey: .createdBy)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        archived = try c.decode(Bool.self, forKey: .archived)
        lastQuantityUpdateDate = try c.decodeIfPresent(Date.self, forKey: .lastQuantityUpdateDate)
        expectedUsageCycleDays = try c.decodeIfPresent(Int.self, forKey: .expectedUsageCycleDays)
        reminderStatus = try c.decodeIfPresent(ReminderStatus.self, forKey: .reminderStatus) ?? .active
        reminderSnoozedUntil = try c.decodeIfPresent(Date.self, forKey: .reminderSnoozedUntil)
    }
}

enum ReminderStatus: String, Codable, Sendable {
    case active
    case snoozed
    case dismissed
}

enum ItemState: String, Sendable {
    case active
    case lowStock
    case expiringSoon
    case expired
    case stale
    case archived
}

extension PantryItem {
    /// Default expected usage cycle in days per category
    static func defaultUsageCycleDays(for category: String) -> Int {
        switch category.lowercased() {
        case "fruits": return 7
        case "vegetables": return 5
        case "dairy": return 7
        case "meat": return 5
        case "seafood": return 3
        case "grains": return 30
        case "snacks": return 14
        case "beverages": return 14
        case "frozen": return 60
        case "condiments": return 90
        case "bakery": return 5
        case "canned": return 180
        case "african staples": return 60
        case "african spices": return 90
        default: return 14
        }
    }

    func validate() -> [String] {
        var errors: [String] = []
        if name.isEmpty || name.count > 120 {
            errors.append("Name must be 1–120 characters.")
        }
        if quantity < 0 || quantity > 1_000_000 {
            errors.append("Quantity must be 0–1,000,000.")
        }
        if category.isEmpty || category.count > 40 {
            errors.append("Category must be 1–40 characters.")
        }
        if let expiry = expiryDate,
           expiry > Date.now.addingTimeInterval(5 * 365.25 * 24 * 60 * 60) {
            errors.append("Expiry date must be within 5 years.")
        }
        if let cost = costPerUnitMinor, cost < 0 {
            errors.append("Cost per unit cannot be negative.")
        }
        return errors
    }
}
