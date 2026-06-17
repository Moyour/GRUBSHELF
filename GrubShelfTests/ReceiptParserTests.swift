import Foundation
import Testing
@testable import GrubShelf

struct ReceiptParserTests {

    // MARK: - Helpers

    /// Builds OCR-style input lines with sequential Y positions (top to bottom).
    private func lines(_ texts: [String]) -> [(text: String, y: CGFloat)] {
        texts.enumerated().map { (index, text) in
            (text: text, y: CGFloat(1.0 - Double(index) / max(Double(texts.count), 1.0)))
        }
    }

    // MARK: - Basic parsing

    @Test func basicParsingExtractsStoreAndTotal() {
        let input = lines([
            "TESCO EXPRESS",
            "Milk £1.50",
            "Bread £2.00",
            "TOTAL £3.50"
        ])
        let result = ReceiptParser.parse(input)
        #expect(result.storeName == "TESCO EXPRESS")
        #expect(result.totalMinor == 350)
        #expect(result.items.count >= 2)
    }

    @Test func returnsNilTotalWhenMissing() {
        let input = lines([
            "Corner Shop",
            "Apples £1.00"
        ])
        let result = ReceiptParser.parse(input)
        #expect(result.totalMinor == nil)
    }

    // MARK: - Quantity patterns

    @Test func trailingLowercaseXQuantity() {
        let input = lines([
            "Shop",
            "Milk x3 £4.50",
            "TOTAL £4.50"
        ])
        let result = ReceiptParser.parse(input)
        let milk = result.items.first { $0.name == "Milk" }
        #expect(milk != nil)
        #expect(milk?.quantity == 3)
    }

    @Test func trailingUppercaseXQuantity() {
        let input = lines([
            "Shop",
            "Milk X2 £3.00",
            "TOTAL £3.00"
        ])
        let result = ReceiptParser.parse(input)
        let milk = result.items.first { $0.name == "Milk" }
        #expect(milk != nil)
        #expect(milk?.quantity == 2)
    }

    @Test func leadingQuantityWithX() {
        let input = lines([
            "Shop",
            "2x Milk £3.00",
            "TOTAL £3.00"
        ])
        let result = ReceiptParser.parse(input)
        let milk = result.items.first { $0.name == "Milk" }
        #expect(milk != nil)
        #expect(milk?.quantity == 2)
    }

    @Test func qtyPrefixQuantity() {
        let input = lines([
            "Shop",
            "QTY 3 Bananas £1.50",
            "TOTAL £1.50"
        ])
        let result = ReceiptParser.parse(input)
        let item = result.items.first
        #expect(item != nil)
        #expect(item?.quantity == 3)
    }

    @Test func atPriceQuantity() {
        let input = lines([
            "Shop",
            "Oranges 2 @ $1.50 $3.00",
            "TOTAL $3.00"
        ])
        let result = ReceiptParser.parse(input)
        let item = result.items.first
        #expect(item != nil)
        #expect(item?.quantity == 2)
    }

    // MARK: - Discount handling

    @Test func discountSubtractedFromTotal() {
        let input = lines([
            "Shop",
            "Milk £3.00",
            "Bread £2.00",
            "DISCOUNT -£1.00",
            "TOTAL £5.00"
        ])
        let result = ReceiptParser.parse(input)
        // Total should be 500 - 100 = 400
        #expect(result.totalMinor == 400)
    }

    @Test func discountLinesExcludedFromItems() {
        let input = lines([
            "Shop",
            "Milk £3.00",
            "COUPON -£0.50",
            "TOTAL £2.50"
        ])
        let result = ReceiptParser.parse(input)
        let hasDiscount = result.items.contains { $0.name.uppercased().contains("COUPON") }
        #expect(!hasDiscount)
    }

    @Test func multipleDiscountsAccumulated() {
        let input = lines([
            "Shop",
            "Milk £5.00",
            "DISCOUNT -£1.00",
            "SAVINGS -£0.50",
            "TOTAL £5.00"
        ])
        let result = ReceiptParser.parse(input)
        // Total should be 500 - 100 - 50 = 350
        #expect(result.totalMinor == 350)
    }
}
