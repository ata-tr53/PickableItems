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

private enum MockSearchError: Error, Equatable {
    case networkFailed
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

        let useCoordinator = KeyboardPickableItemCoordinator(
            allItems: [lowUseClose, mediumUseExact, highUseAlias],
            selectedItems: [],
            sortingStrategy: .pureUseAmount
        )
        useCoordinator.updateNotSelectedItems(text: "swift", debounce: false)
        #expect(useCoordinator.notSelectedItems.map(\.title) == ["Project Alpha", "Swift", "Swifty"])

        let mixedCoordinator = KeyboardPickableItemCoordinator(
            allItems: [lowUseClose, mediumUseExact, highUseAlias],
            selectedItems: [],
            sortingStrategy: .mixed(penaltyMultiplier: 2.0)
        )
        mixedCoordinator.updateNotSelectedItems(text: "swift", debounce: false)
        #expect(mixedCoordinator.notSelectedItems.map(\.title) == ["Swift", "Project Alpha", "Swifty"])

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
        coordinator.selectItem(mutatedCopy)

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

    @Test func remoteSearchProviderPreservesServerOrderAndFiltersSelectedItems() async throws {
        let selected = MockItem(title: "Already Picked", useAmount: 100)
        let first = MockItem(title: "Server First", useAmount: 1)
        let second = MockItem(title: "Server Second", useAmount: 50)

        var receivedQueries: [String] = []
        let coordinator = KeyboardPickableItemCoordinator<MockItem>(
            selectedItems: [selected],
            debounceDuration: .milliseconds(10)
        ) { query in
            receivedQueries.append(query)
            return [first, selected, second]
        }

        coordinator.updateNotSelectedItems(text: "  angst  ", debounce: false)
        try await Task.sleep(for: .milliseconds(30))

        #expect(receivedQueries == ["angst"])
        #expect(coordinator.isLoading == false)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Server First", "Server Second"])

        // Deselecting restores the item in server order without triggering another remote call
        coordinator.deselectItem(selected)
        #expect(receivedQueries.count == 1)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Server First", "Already Picked", "Server Second"])
    }

    @Test func remoteSearchProviderCapturesErrorsAndRecovers() async throws {
        var shouldFail = true
        let fallbackItem = MockItem(title: "Recovered")

        let coordinator = KeyboardPickableItemCoordinator<MockItem>(
            debounceDuration: .milliseconds(10)
        ) { _ in
            if shouldFail {
                throw MockSearchError.networkFailed
            }
            return [fallbackItem]
        }

        coordinator.updateNotSelectedItems(text: "test", debounce: false)
        try await Task.sleep(for: .milliseconds(30))

        #expect(coordinator.isLoading == false)
        #expect(coordinator.searchError as? MockSearchError == .networkFailed)

        shouldFail = false
        coordinator.updateNotSelectedItems(text: "test2", debounce: false)
        try await Task.sleep(for: .milliseconds(30))

        #expect(coordinator.isLoading == false)
        #expect(coordinator.searchError == nil)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Recovered"])
    }

    @Test func remoteSearchProviderCancelsStaleRequests() async throws {
        let staleItem = MockItem(title: "Stale")
        let freshItem = MockItem(title: "Fresh")

        let coordinator = KeyboardPickableItemCoordinator<MockItem>(
            debounceDuration: .milliseconds(10)
        ) { query in
            if query == "slow" {
                try await Task.sleep(for: .milliseconds(100))
                return [staleItem]
            }
            try await Task.sleep(for: .milliseconds(10))
            return [freshItem]
        }

        coordinator.updateNotSelectedItems(text: "slow", debounce: false)
        try await Task.sleep(for: .milliseconds(15))
        coordinator.updateNotSelectedItems(text: "fast", debounce: false)

        try await Task.sleep(for: .milliseconds(130))

        #expect(coordinator.isLoading == false)
        #expect(coordinator.notSelectedItems.map(\.title) == ["Fresh"])
    }
}
