import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct ReceiptConfirmationViewModelTests {
    private let householdId = UUID()

    private func makeParsedReceipt(
        totalMinor: Int? = 5000,
        linePrices: [Int] = []
    ) -> ParsedReceipt {
        let items = linePrices.enumerated().map { index, price in
            ParsedReceiptItem(name: "Item \(index + 1)", priceMinor: price)
        }
        return ParsedReceipt(
            items: items.isEmpty ? [ParsedReceiptItem(name: "Milk", priceMinor: nil)] : items,
            totalMinor: totalMinor,
            storeName: "Test Store",
            date: .now
        )
    }

    // MARK: - canLogPurchase

    @Test func canLogPurchaseIsFalseWhenTotalEmpty() {
        let vm = ReceiptConfirmationViewModel()
        vm.manualTotalText = ""
        #expect(!vm.canLogPurchase)
    }

    @Test func canLogPurchaseIsFalseWhenTotalZero() {
        let vm = ReceiptConfirmationViewModel()
        vm.manualTotalText = "0"
        #expect(!vm.canLogPurchase)
    }

    @Test func canLogPurchaseIsTrueWhenManualTotalPositive() {
        let vm = ReceiptConfirmationViewModel()
        vm.manualTotalText = "12.50"
        #expect(vm.canLogPurchase)
    }

    // MARK: - resolvedAmountMinor priority

    @Test func resolvedAmountPrefersManualTextOverReceiptTotal() {
        var receipt = makeParsedReceipt(totalMinor: 5000)
        receipt = ParsedReceipt(
            items: receipt.items,
            totalMinor: 5000,
            storeName: receipt.storeName,
            date: receipt.date
        )
        let vm = ReceiptConfirmationViewModel(parsedReceipt: receipt)
        vm.manualTotalText = "9.99"
        #expect(vm.resolvedAmountMinor() == 999)
    }

    @Test func resolvedAmountUsesReceiptTotalWhenManualEmpty() {
        let vm = ReceiptConfirmationViewModel(parsedReceipt: makeParsedReceipt(totalMinor: 4200))
        vm.manualTotalText = ""
        #expect(vm.resolvedAmountMinor() == 4200)
    }

    @Test func resolvedAmountSumsLinePricesWhenNoTotal() {
        let vm = ReceiptConfirmationViewModel(
            parsedReceipt: ParsedReceipt(
                items: [
                    ParsedReceiptItem(name: "A", priceMinor: 150),
                    ParsedReceiptItem(name: "B", priceMinor: 250)
                ],
                totalMinor: nil
            )
        )
        vm.manualTotalText = ""
        #expect(vm.resolvedAmountMinor() == 400)
    }

    // MARK: - Prefill

    @Test func loadSuggestedTotalIfNeededPrefillsWhenEmpty() async {
        let tripRepo = MockShoppingTripRepository()
        tripRepo.tripsByDateRange = [
            ShoppingTrip(
                tripId: UUID(),
                householdId: householdId,
                shoppingListId: nil,
                date: .now,
                totalCostMinor: 3599,
                itemCount: 1,
                period: "2026-05",
                costLogged: true
            )
        ]
        let vm = ReceiptConfirmationViewModel()

        await vm.loadSuggestedTotalIfNeeded(
            householdId: householdId,
            shoppingTripRepository: tripRepo
        )

        #expect(vm.didPrefillTotal)
        #expect(vm.manualTotalText == "35.99")
    }

    @Test func loadSuggestedTotalIfNeededSkipsWhenManualAlreadySet() async {
        let tripRepo = MockShoppingTripRepository()
        tripRepo.tripsByDateRange = [
            ShoppingTrip(
                tripId: UUID(),
                householdId: householdId,
                shoppingListId: nil,
                date: .now,
                totalCostMinor: 1000,
                itemCount: 1,
                period: "2026-05",
                costLogged: true
            )
        ]
        let vm = ReceiptConfirmationViewModel()
        vm.manualTotalText = "5.00"

        await vm.loadSuggestedTotalIfNeeded(
            householdId: householdId,
            shoppingTripRepository: tripRepo
        )

        #expect(!vm.didPrefillTotal)
        #expect(vm.manualTotalText == "5.00")
    }

    // MARK: - Pantry auto-add

    @Test func addToPantryDefaultsToTrue() {
        let receipt = makeParsedReceipt(totalMinor: 5000, linePrices: [200, 300])
        let vm = ReceiptConfirmationViewModel(parsedReceipt: receipt)
        for item in vm.items {
            #expect(item.addToPantry)
        }
    }

    @Test func pantrySelectionCountReflectsToggles() {
        let receipt = makeParsedReceipt(totalMinor: 5000, linePrices: [200, 300, 400])
        let vm = ReceiptConfirmationViewModel(parsedReceipt: receipt)
        #expect(vm.pantrySelectionCount == 3)

        vm.togglePantrySelection(id: vm.items[0].id)
        #expect(vm.pantrySelectionCount == 2)

        vm.togglePantrySelection(id: vm.items[1].id)
        #expect(vm.pantrySelectionCount == 1)

        // Toggle back on
        vm.togglePantrySelection(id: vm.items[0].id)
        #expect(vm.pantrySelectionCount == 2)
    }

    @Test func canAddToPantryFalseWithoutDeps() {
        let vm = ReceiptConfirmationViewModel()
        #expect(!vm.canAddToPantry)
    }

    @Test func canAddToPantryTrueWithDeps() {
        let vm = ReceiptConfirmationViewModel(
            pantryRepository: MockPantryRepository(),
            householdId: UUID(),
            userId: UUID(),
            userRole: .member
        )
        #expect(vm.canAddToPantry)
    }
}
