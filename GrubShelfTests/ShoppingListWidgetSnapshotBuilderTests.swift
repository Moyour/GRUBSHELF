import Foundation
import Testing
@testable import GrubShelf

/// Shared App Group `UserDefaults` — must run serially so `clearStalePinWhenListNoLongerActive` does not clear another test's pin.
@Suite(.serialized)
struct ShoppingListWidgetSnapshotBuilderTests {
    @Test func buildsPayloadsForActiveListsOnly() {
        let hid = UUID()
        let uid = UUID()
        let listA = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "A",
            createdBy: uid,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            transferred: false
        )
        let listB = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "B",
            createdBy: uid,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200),
            transferred: false
        )
        let transferredList = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Done",
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now,
            transferred: true
        )

        let item1 = ShoppingItem(
            itemId: UUID(),
            householdId: hid,
            listId: listB.listId,
            name: "Milk",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now
        )

        let snapshot = ShoppingListWidgetSnapshotBuilder.build(
            lists: [listA, transferredList, listB],
            items: [item1]
        )

        #expect(snapshot.lists.count == 2)
        #expect(snapshot.lists.first?.listId == listB.listId)
        #expect(snapshot.lists.first?.pendingCount == 1)
        #expect(snapshot.lists.first?.pendingSampleTitles.contains("Milk") == true)
        #expect(snapshot.totalPendingCount == 1)
    }

    @Test func sortsByNewestListCreatedAtNotItemActivity() {
        let hid = UUID()
        let uid = UUID()
        let olderListBusyItems = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Older list",
            createdBy: uid,
            createdAt: Date(timeIntervalSince1970: 50),
            updatedAt: Date(timeIntervalSince1970: 500),
            transferred: false
        )
        let newerList = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Newer list",
            createdBy: uid,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 100),
            transferred: false
        )

        let itemOnOlderList = ShoppingItem(
            itemId: UUID(),
            householdId: hid,
            listId: olderListBusyItems.listId,
            name: "Milk",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: uid,
            createdAt: .now,
            updatedAt: Date(timeIntervalSince1970: 9000)
        )

        let snapshot = ShoppingListWidgetSnapshotBuilder.build(
            lists: [olderListBusyItems, newerList],
            items: [itemOnOlderList]
        )

        #expect(snapshot.lists.first?.listId == newerList.listId)
        #expect(snapshot.lists.first?.pendingCount == 0)
        #expect(snapshot.lists.count == 2)
        #expect(snapshot.lists.last?.pendingSampleTitles.contains("Milk") == true)
    }

    @Test func respectsPinnedListOverActivity() {
        let hid = UUID()
        let uid = UUID()
        let pinned = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Pinned",
            createdBy: uid,
            createdAt: .now,
            updatedAt: Date(timeIntervalSince1970: 10),
            transferred: false
        )
        let busier = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Busy",
            createdBy: uid,
            createdAt: .now,
            updatedAt: Date(timeIntervalSince1970: 5000),
            transferred: false
        )

        let widgetDefaults = UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier)
        widgetDefaults?.removeObject(forKey: "shoppingWidgetPinnedListId")
        widgetDefaults?.set(pinned.listId.uuidString, forKey: "shoppingWidgetPinnedListId")
        defer {
            widgetDefaults?.removeObject(forKey: "shoppingWidgetPinnedListId")
        }

        let snapshot = ShoppingListWidgetSnapshotBuilder.build(lists: [busier, pinned], items: [])
        #expect(snapshot.lists.first?.listId == pinned.listId)
    }

    @Test func capsSampleTitles() {
        let hid = UUID()
        let uid = UUID()
        let list = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Big",
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )

        var items: [ShoppingItem] = []
        for i in 0 ..< 20 {
            items.append(
                ShoppingItem(
                    itemId: UUID(),
                    householdId: hid,
                    listId: list.listId,
                    name: "Item \(i)",
                    quantity: 1,
                    unit: nil,
                    category: nil,
                    completed: false,
                    transferred: false,
                    createdBy: uid,
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        }

        let snapshot = ShoppingListWidgetSnapshotBuilder.build(lists: [list], items: items)
        #expect(snapshot.lists.first?.pendingSampleTitles.count == ShoppingListWidgetSnapshotBuilder.maxTitlesPerList)
        #expect(snapshot.lists.first?.pendingCount == 20)
        #expect(snapshot.totalPendingCount == 20)
    }

    @Test func clearsStalePinWhenListNoLongerActive() {
        let staleId = UUID()
        UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier)?
            .set(staleId.uuidString, forKey: "shoppingWidgetPinnedListId")
        defer {
            UserDefaults(suiteName: ShoppingListWidgetAppGroup.identifier)?
                .removeObject(forKey: "shoppingWidgetPinnedListId")
        }

        ShoppingListWidgetPreferences.clearStalePinIfNeeded(activeNonTransferredListIds: [])

        #expect(ShoppingListWidgetPreferences.pinnedListId() == nil)
    }

    @Test func keepsPinWhenListStillActive() {
        let hid = UUID()
        let uid = UUID()
        let list = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Kept",
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )
        ShoppingListWidgetPreferences.setPinnedList(list.listId)
        defer { ShoppingListWidgetPreferences.clearPinnedList() }
        #expect(ShoppingListWidgetPreferences.pinnedListId() == list.listId)

        ShoppingListWidgetPreferences.clearStalePinIfNeeded(activeNonTransferredListIds: [list.listId])

        #expect(ShoppingListWidgetPreferences.pinnedListId() == list.listId)
    }

    @Test func applyingMarkDoneUpdatesCountsAndSamples() {
        let listId = UUID()
        let milkId = UUID()
        let snap = ShoppingListWidgetSnapshot(
            updatedAt: .now,
            lists: [
                ShoppingListWidgetListPayload(
                    listId: listId,
                    name: "Test",
                    pendingSamples: [
                        ShoppingListWidgetPendingLine(itemId: milkId, title: "Milk"),
                        ShoppingListWidgetPendingLine(itemId: UUID(), title: "Eggs"),
                    ],
                    pendingCount: 2,
                    completedCount: 0
                ),
            ],
            totalPendingCount: 2
        )
        let next = snap.applyingMarkDone(itemId: milkId)
        #expect(next.totalPendingCount == 1)
        #expect(next.lists.first?.pendingCount == 1)
        #expect(next.lists.first?.completedCount == 1)
        #expect(next.lists.first?.pendingSamples.contains(where: { $0.title == "Milk" }) == false)
        #expect(next.lists.first?.pendingSamples.contains(where: { $0.title == "Eggs" }) == true)
    }

    @Test func decodesLegacySnapshotWithTitleStringsOnly() throws {
        let listId = UUID()
        let json = """
        {"updatedAt":"2020-01-01T00:00:00Z","lists":[{"listId":"\(listId.uuidString)","name":"L","pendingSampleTitles":["A","B"],"pendingCount":2,"completedCount":0}],"totalPendingCount":2}
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let snap = try dec.decode(ShoppingListWidgetSnapshot.self, from: json)
        #expect(snap.lists.first?.pendingSamples.count == 2)
        #expect(snap.lists.first?.pendingSamples.allSatisfy { $0.itemId == nil } == true)
        #expect(snap.lists.first?.pendingSampleTitles == ["A", "B"])
    }

    @Test func includesQuantityInPendingLines() {
        let hid = UUID()
        let uid = UUID()
        let list = ShoppingList(
            listId: UUID(),
            householdId: hid,
            name: "Weekly",
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now,
            transferred: false
        )

        let milk = ShoppingItem(
            itemId: UUID(),
            householdId: hid,
            listId: list.listId,
            name: "Milk",
            quantity: 2,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now
        )

        let eggs = ShoppingItem(
            itemId: UUID(),
            householdId: hid,
            listId: list.listId,
            name: "Eggs",
            quantity: 3.5,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now
        )

        let bread = ShoppingItem(
            itemId: UUID(),
            householdId: hid,
            listId: list.listId,
            name: "Bread",
            quantity: 1,
            unit: nil,
            category: nil,
            completed: false,
            transferred: false,
            createdBy: uid,
            createdAt: .now,
            updatedAt: .now
        )

        let snapshot = ShoppingListWidgetSnapshotBuilder.build(
            lists: [list],
            items: [milk, eggs, bread]
        )

        #expect(snapshot.lists.count == 1)
        #expect(snapshot.lists.first?.pendingSamples.count == 3)

        // Verify quantities are included in pending lines
        let milkLine = snapshot.lists.first?.pendingSamples.first { $0.title == "Milk" }
        let eggsLine = snapshot.lists.first?.pendingSamples.first { $0.title == "Eggs" }
        let breadLine = snapshot.lists.first?.pendingSamples.first { $0.title == "Bread" }

        #expect(milkLine?.quantity == 2)
        #expect(eggsLine?.quantity == 3.5)
        #expect(breadLine?.quantity == 1)
    }

    @Test func decodesSnapshotWithoutQuantityFieldForBackwardCompatibility() throws {
        // Simulates snapshot created by older app version without quantity field
        let listId = UUID()
        let itemId = UUID()
        let json = """
        {"updatedAt":"2020-01-01T00:00:00Z","lists":[{"listId":"\(listId.uuidString)","name":"L","pendingSamples":[{"itemId":"\(itemId.uuidString)","title":"Milk"}],"pendingCount":1,"completedCount":0}],"totalPendingCount":1}
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let snap = try dec.decode(ShoppingListWidgetSnapshot.self, from: json)

        #expect(snap.lists.first?.pendingSamples.count == 1)
        let line = snap.lists.first?.pendingSamples.first
        #expect(line?.itemId == itemId)
        #expect(line?.title == "Milk")
        #expect(line?.quantity == nil) // Should be nil for backward compatibility
    }

    @Test func encodesAndDecodesQuantityFieldCorrectly() throws {
        let line = ShoppingListWidgetPendingLine(
            itemId: UUID(),
            title: "Flour",
            quantity: 2.5
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode([line])

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode([ShoppingListWidgetPendingLine].self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded.first?.title == "Flour")
        #expect(decoded.first?.quantity == 2.5)
    }
}
