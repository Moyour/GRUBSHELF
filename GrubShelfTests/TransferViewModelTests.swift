import Testing
import Foundation
@testable import GrubShelf

@MainActor
struct TransferViewModelTests {
    private let householdId = UUID()
    private let userId = UUID()
    private let listId = UUID()

    private func makeShoppingItem(name: String = "Milk") -> ShoppingItem {
        ShoppingItem(
            itemId: UUID(),
            householdId: householdId,
            listId: listId,
            name: name,
            quantity: 1,
            unit: .pcs,
            category: "Dairy",
            completed: true,
            createdBy: userId,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(
        tripRepository: MockShoppingTripRepository = MockShoppingTripRepository(),
        items: [ShoppingItem] = []
    ) -> (TransferViewModel, MockShoppingTripRepository) {
        let resolvedItems = items.isEmpty ? [makeShoppingItem()] : items
        let vm = TransferViewModel(
            completedItems: resolvedItems,
            pantryRepository: MockPantryRepository(),
            transactionRepository: MockTransactionRepository(),
            shoppingRepository: MockShoppingRepository(),
            shoppingTripRepository: tripRepository,
            shoppingListRepository: MockShoppingListRepository(),
            financeSettingsRepository: MockFinanceSettingsRepository(),
            wasteEventRepository: MockWasteEventRepository(),
            householdId: householdId,
            userId: userId,
            listId: listId
        )
        return (vm, tripRepository)
    }

    // MARK: - canTransfer

    @Test func canTransferIsTrueWhenTripTotalEmpty() {
        let (vm, _) = makeViewModel()
        vm.tripTotalCost = ""
        #expect(vm.canTransfer)
    }

    @Test func canTransferIsFalseWhenTripTotalZero() {
        let (vm, _) = makeViewModel()
        vm.tripTotalCost = "0"
        #expect(!vm.canTransfer)
    }

    @Test func canTransferIsTrueWhenTripTotalPositive() {
        let (vm, _) = makeViewModel()
        vm.tripTotalCost = "42.50"
        #expect(vm.canTransfer)
    }

    // MARK: - Prefill

    @Test func loadSuggestedTripTotalPrefillsFromLastLoggedShop() async {
        let tripRepo = MockShoppingTripRepository()
        tripRepo.tripsByDateRange = [
            ShoppingTrip(
                tripId: UUID(),
                householdId: householdId,
                shoppingListId: nil,
                date: .now,
                totalCostMinor: 4599,
                itemCount: 3,
                period: "2026-05",
                costLogged: true
            )
        ]
        let (vm, _) = makeViewModel(tripRepository: tripRepo)

        await vm.loadSuggestedTripTotal()

        #expect(vm.didPrefillTripTotal)
        #expect(vm.tripTotalCost == "45.99")
    }

    @Test func loadSuggestedTripTotalSkipsUnloggedTrips() async {
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
                costLogged: false
            ),
            ShoppingTrip(
                tripId: UUID(),
                householdId: householdId,
                shoppingListId: nil,
                date: .now.addingTimeInterval(-3600),
                totalCostMinor: 2500,
                itemCount: 2,
                period: "2026-05",
                costLogged: true
            )
        ]
        let (vm, _) = makeViewModel(tripRepository: tripRepo)

        await vm.loadSuggestedTripTotal()

        #expect(vm.didPrefillTripTotal)
        #expect(vm.tripTotalCost == "25")
    }

    // MARK: - Trip logging

    @Test func executeTransferLogsTripWithCostLoggedTrue() async {
        let tripRepo = MockShoppingTripRepository()
        let (vm, repo) = makeViewModel(tripRepository: tripRepo)
        vm.tripTotalCost = "18.75"

        let success = await vm.executeTransfer()

        #expect(success)
        #expect(repo.addedTrips.count == 1)
        guard let trip = repo.addedTrips.first else {
            Issue.record("Expected a logged shopping trip")
            return
        }
        #expect(trip.costLogged)
        #expect(trip.totalCostMinor == 1875)
        #expect(trip.shoppingListId == listId)
        #expect(trip.itemCount == vm.transferItems.count)
    }

    @Test func formatMajorAmountRoundsWholeNumbersWithoutDecimals() {
        #expect(TransferViewModel.formatMajorAmount(fromMinor: 4200) == "42")
    }
}
