import Foundation
import Testing
@testable import PickableItems

private struct MockItem: KeyboardPickableItem {
    let id: UUID
    let title: String
    var secondaryNames: [String]
    var useAmount: Int

    init(
        id: UUID = UUID(),
        title: String,
        secondaryNames: [String] = [],
        useAmount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.secondaryNames = secondaryNames
        self.useAmount = useAmount
    }
}

private struct MinimalItem: KeyboardPickableItem {
    let id = UUID()
    let title: String
}

@Suite("Levenshtein Distance")
struct LevenshteinTests {
    @Test func identicalStringsHaveZeroDistance() {
        #expect("swiftui".levenshteinDistance(to: "swiftui") == 0)
        #expect("".levenshteinDistance(to: "") == 0)
    }

    @Test func emptyStringDistanceEqualsLength() {
        #expect("".levenshteinDistance(to: "abc") == 3)
        #expect("hello".levenshteinDistance(to: "") == 5)
    }

    @Test func classicEditDistances() {
        #expect("kitten".levenshteinDistance(to: "sitting") == 3)
        #expect("swiftui".levenshteinDistance(to: "swfitui") == 2)
        #expect("combine".levenshteinDistance(to: "combin") == 1)
    }
}

@Suite("KeyboardPickableItemCoordinator")
@MainActor
struct CoordinatorTests {
    @Test func protocolDefaultsWorkForMinimalModels() {
        let item = MinimalItem(title: "Simple")
        #expect(item.secondaryNames.isEmpty)
        #expect(item.useAmount == 0)
    }

    @Test func initPopulatesNotSelectedItemsSortedByUseAmount() {
        let a = MockItem(title: "Alpha", useAmount: 5)
        let b = MockItem(title: "Beta", useAmount: 20)
        let c = MockItem(title: "Gamma", useAmount: 10)

        let coordinator = KeyboardPickableItemCoordinator(
            allItems: [a, b, c],
            selectedItems: [b]
        )

        #expect(coordinator.notSelectedItems.map(\.title) == ["Gamma", "Alpha"])
    }

    @Test func shortQueriesRequireSubstringMatch() {
        let alice = MockItem(title: "Alice", useAmount: 5)
        let bob = MockItem(title: "Bob", useAmount: 50)
        let charlie = MockItem(title: "Charlie", useAmount: 8)

        let coordinator = KeyboardPickableItemCoordinator(
            allItems: [alice, bob, charlie],
            selectedItems: []
        )

        coordinator.updateNotSelectedItems(text: "a", debounce: false)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Charlie", "Alice"])
    }

    @Test func longerQueriesMatchFuzzyTypos() {
        let swiftUI = MockItem(title: "SwiftUI", useAmount: 20)
        let combine = MockItem(title: "Combine", useAmount: 10)

        let coordinator = KeyboardPickableItemCoordinator(
            allItems: [swiftUI, combine],
            selectedItems: []
        )

        coordinator.updateNotSelectedItems(text: "SwfitUI", debounce: false)
        #expect(coordinator.notSelectedItems.map(\.title) == ["SwiftUI"])
    }

    @Test func sortingStrategiesRankMatchesAsExpected() {
        let highUseAlias = MockItem(
            title: "Project Alpha",
            secondaryNames: ["swift"],
            useAmount: 100
        )
        let mediumUseExact = MockItem(
            title: "Swift",
            useAmount: 60
        )
        let lowUseClose = MockItem(
            title: "Swifty",
            useAmount: 10
        )

        // Pure use amount: 100 > 60 > 10
        let useCoordinator = KeyboardPickableItemCoordinator(
            allItems: [lowUseClose, mediumUseExact, highUseAlias],
            selectedItems: [],
            sortingStrategy: .pureUseAmount
        )
        useCoordinator.updateNotSelectedItems(text: "swift", debounce: false)
        #expect(useCoordinator.notSelectedItems.map(\.title) == ["Project Alpha", "Swift", "Swifty"])

        // Mixed with default 2.0 alias penalty:
        // Swift: (60+1)/1 = 61, Project Alpha (alias): (100+1)/(1*2) = 50.5, Swifty: (10+1)/1 = 11
        let mixedCoordinator = KeyboardPickableItemCoordinator(
            allItems: [lowUseClose, mediumUseExact, highUseAlias],
            selectedItems: [],
            sortingStrategy: .mixed(penaltyMultiplier: 2.0)
        )
        mixedCoordinator.updateNotSelectedItems(text: "swift", debounce: false)
        #expect(mixedCoordinator.notSelectedItems.map(\.title) == ["Swift", "Project Alpha", "Swifty"])

        // Pure distance: distance 0 beats distance 1
        let exactItem = MockItem(title: "Swift", useAmount: 1)
        let typoItem = MockItem(title: "Swiff", useAmount: 100)
        let distanceCoordinator = KeyboardPickableItemCoordinator(
            allItems: [typoItem, exactItem],
            selectedItems: [],
            sortingStrategy: .pureDistance
        )
        distanceCoordinator.updateNotSelectedItems(text: "swift", debounce: false)
        #expect(distanceCoordinator.notSelectedItems.map(\.title) == ["Swift", "Swiff"])
    }

    @Test func selectAndDeselectMatchByIDAndInvokeCallback() {
        let sharedID = UUID()
        let original = MockItem(id: sharedID, title: "SwiftUI", useAmount: 10)
        let mutatedCopy = MockItem(id: sharedID, title: "SwiftUI", useAmount: 11)
        let other = MockItem(title: "Combine", useAmount: 5)

        var callbackTitles: [String] = []
        let coordinator = KeyboardPickableItemCoordinator(
            allItems: [original, other],
            selectedItems: [],
            onSelect: { callbackTitles.append($0.title) }
        )

        coordinator.selectItem(original)
        coordinator.selectItem(mutatedCopy) // Should be ignored because ID matches

        #expect(coordinator.selectedItems.count == 1)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Combine"])
        #expect(callbackTitles == ["SwiftUI"])

        coordinator.deselectItem(mutatedCopy)
        #expect(coordinator.selectedItems.isEmpty)
        #expect(coordinator.notSelectedItems.map(\.title) == ["SwiftUI", "Combine"])
    }

    @Test func updatingAllItemsRefreshesNotSelectedItems() {
        let first = MockItem(title: "Work", useAmount: 10)
        let second = MockItem(title: "Urgent", useAmount: 30)

        let coordinator = KeyboardPickableItemCoordinator(
            allItems: [first],
            selectedItems: []
        )
        #expect(coordinator.notSelectedItems.map(\.title) == ["Work"])

        coordinator.allItems.append(second)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Urgent", "Work"])
    }
}
