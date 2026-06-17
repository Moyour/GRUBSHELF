import Foundation

/// Feature keys matching the database `features` JSONB keys.
enum SubscriptionFeature: String, CaseIterable, Sendable {
    case pantryItems = "pantry_items"
    case shoppingLists = "shopping_lists"
    case householdMembers = "household_members"
    case barcodeScansPerMonth = "barcode_scans_per_month"
    case analyticsDays = "analytics_days"
    case exportReports = "export_reports"
    case photoUploads = "photo_uploads"
    case bulkOperations = "bulk_operations"

    /// True for features tracked with monthly counters (barcode scans).
    var isMetered: Bool {
        switch self {
        case .barcodeScansPerMonth: return true
        default: return false
        }
    }

    /// True for features that count existing entities (items, lists, members).
    var isCountBased: Bool {
        switch self {
        case .pantryItems, .shoppingLists, .householdMembers: return true
        default: return false
        }
    }

    /// True for boolean on/off features (export, photos, bulk).
    var isBoolean: Bool {
        switch self {
        case .exportReports, .photoUploads, .bulkOperations: return true
        default: return false
        }
    }

    var displayTitle: String {
        switch self {
        case .pantryItems: return "Pantry Items"
        case .shoppingLists: return "Shopping Lists"
        case .householdMembers: return "Household Members"
        case .barcodeScansPerMonth: return "Barcode Scans"
        case .analyticsDays: return "Analytics History"
        case .exportReports: return "Data Export"
        case .photoUploads: return "Photo Recognition"
        case .bulkOperations: return "Bulk Operations"
        }
    }

    var systemImage: String {
        switch self {
        case .pantryItems: return "refrigerator"
        case .shoppingLists: return "cart"
        case .householdMembers: return "person.2"
        case .barcodeScansPerMonth: return "barcode.viewfinder"
        case .analyticsDays: return "chart.bar"
        case .exportReports: return "square.and.arrow.up"
        case .photoUploads: return "camera"
        case .bulkOperations: return "checkmark.circle"
        }
    }

    var paywallDescription: String {
        switch self {
        case .pantryItems: return "Track unlimited pantry items"
        case .shoppingLists: return "Create unlimited shopping lists"
        case .householdMembers: return "Add unlimited family members"
        case .barcodeScansPerMonth: return "Unlimited barcode scans"
        case .analyticsDays: return "Full analytics history"
        case .exportReports: return "Export data as JSON or CSV"
        case .photoUploads: return "Add items with photo recognition"
        case .bulkOperations: return "Select and manage items in bulk"
        }
    }
}
