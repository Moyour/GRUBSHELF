import Foundation

/// A single line item parsed from a receipt.
struct ParsedReceiptItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var quantity: Double?
    var priceMinor: Int?

    init(id: UUID = UUID(), name: String, quantity: Double? = nil, priceMinor: Int? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.priceMinor = priceMinor
    }
}

/// Structured result of parsing a receipt image.
struct ParsedReceipt: Equatable {
    var items: [ParsedReceiptItem]
    var totalMinor: Int?
    var storeName: String?
    var date: Date?

    init(items: [ParsedReceiptItem], totalMinor: Int? = nil, storeName: String? = nil, date: Date? = nil) {
        self.items = items
        self.totalMinor = totalMinor
        self.storeName = storeName
        self.date = date
    }
}
