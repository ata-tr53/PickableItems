import SwiftUI

/// Coordinates filtering, ranking, selection, and keyboard accessory visibility for a specific `KeyboardPickableItem` type.
@MainActor
@Observable
public class KeyboardPickableItemCoordinator<Item: KeyboardPickableItem> {
    /// The complete list of items available to pick from in local mode. Updating this refreshes `notSelectedItems`.
    public var allItems: [Item] {
        didSet {
            guard searchProvider == nil else { return }
            internalLocalSearch(text: lastQuery)
        }
    }

    /// The currently filtered and ranked items that have not yet been selected.
    public private(set) var notSelectedItems: [Item]

    /// The items currently selected by the user.
    public var selectedItems: [Item]

    /// The ranking strategy used to order search results in local mode. Updating this re-ranks `notSelectedItems`.
    public var sortingStrategy: KeyboardPickableItemSortingStrategy {
        didSet {
            guard searchProvider == nil else { return }
            internalLocalSearch(text: lastQuery)
        }
    }

    /// Delay before triggering a search after text changes (defaults to `300ms`).
    public var debounceDuration: Duration

    /// Optional callback invoked immediately after an item is selected.
    public var onSelect: ((Item) -> Void)?

    /// `true` while an async `searchProvider` request is in flight. Always `false` in local mode.
    public private(set) var isLoading: Bool = false

    /// The most recent non-cancellation error thrown by `searchProvider`, cleared when a new search starts.
    public private(set) var searchError: (any Error)? = nil

    internal var activeAccessoryID: UUID? = nil

    private let searchProvider: ((String) async throws -> [Item])?
    private var searchTask: Task<Void, Never>? = nil
    private var searchGeneration: Int = 0
    private var lastQuery: String = ""
    private var lastRemoteResults: [Item] = []

    /// Creates a coordinator backed by a local in-memory list of items with built-in fuzzy search and ranking.
    /// - Parameters:
    ///   - allItems: The full pool of pickable items.
    ///   - selectedItems: Initially selected items (defaults to empty).
    ///   - sortingStrategy: Strategy used to rank matching items (defaults to `.mixed()`).
    ///   - debounceDuration: Delay before searching while the user types (defaults to `300ms`).
    ///   - onSelect: Optional callback invoked whenever an item is selected.
    public init(
        allItems: [Item],
        selectedItems: [Item] = [],
        sortingStrategy: KeyboardPickableItemSortingStrategy = .mixed(),
        debounceDuration: Duration = .milliseconds(300),
        onSelect: ((Item) -> Void)? = nil
    ) {
        self.allItems = allItems
        self.selectedItems = selectedItems
        self.sortingStrategy = sortingStrategy
        self.debounceDuration = debounceDuration
        self.onSelect = onSelect
        self.searchProvider = nil

        let selectedIDs = Set(selectedItems.map(\.id))
        self.notSelectedItems = allItems
            .filter { !selectedIDs.contains($0.id) }
            .sorted { $0.useAmount > $1.useAmount }
    }

    /// Creates a coordinator backed by an external or async search provider (such as a remote autocomplete API).
    /// Results returned by `searchProvider` keep their original order and are only filtered to exclude `selectedItems`.
    /// - Parameters:
    ///   - selectedItems: Initially selected items (defaults to empty).
    ///   - debounceDuration: Delay before invoking `searchProvider` while the user types (defaults to `300ms`).
    ///   - onSelect: Optional callback invoked whenever an item is selected.
    ///   - searchProvider: Closure that receives the trimmed search query and returns pre-sorted matching items.
    public init(
        selectedItems: [Item] = [],
        debounceDuration: Duration = .milliseconds(300),
        onSelect: ((Item) -> Void)? = nil,
        searchProvider: @escaping (String) async throws -> [Item]
    ) {
        self.allItems = []
        self.notSelectedItems = []
        self.selectedItems = selectedItems
        self.sortingStrategy = .mixed()
        self.debounceDuration = debounceDuration
        self.onSelect = onSelect
        self.searchProvider = searchProvider
    }

    /// Returns `true` when any `TextField` bridged to this coordinator is currently focused.
    public var isTextFieldFocused: Bool { activeAccessoryID != nil }

    internal func updateNotSelectedItems(text: String, debounce: Bool = true) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        lastQuery = text

        if let provider = searchProvider {
            let trimmedQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            searchError = nil
            isLoading = true

            searchTask = Task { [weak self] in
                if debounce {
                    do {
                        try await Task.sleep(for: self?.debounceDuration ?? .milliseconds(300))
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled, let self, self.searchGeneration == generation else { return }

                do {
                    let results = try await provider(trimmedQuery)
                    guard !Task.isCancelled, self.searchGeneration == generation else { return }
                    self.lastRemoteResults = results
                    let selectedIDs = Set(self.selectedItems.map(\.id))
                    self.notSelectedItems = results.filter { !selectedIDs.contains($0.id) }
                    self.isLoading = false
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled, self.searchGeneration == generation else { return }
                    self.searchError = error
                    self.isLoading = false
                }
            }
            return
        }

        if !debounce {
            internalLocalSearch(text: text)
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: self?.debounceDuration ?? .milliseconds(300))
            } catch {
                return
            }
            guard !Task.isCancelled, let self, self.searchGeneration == generation else { return }
            self.internalLocalSearch(text: text)
        }
    }

    internal func reapplySelectionFilter() {
        if searchProvider != nil {
            let selectedIDs = Set(selectedItems.map(\.id))
            notSelectedItems = lastRemoteResults.filter { !selectedIDs.contains($0.id) }
        } else {
            internalLocalSearch(text: lastQuery)
        }
    }

    private func maxAllowedDistance(for queryLength: Int) -> Int {
        switch queryLength {
        case ...2: return 0
        case 3...4: return 1
        case 5...7: return 2
        default: return 3
        }
    }

    private func internalLocalSearch(text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedIDs = Set(selectedItems.map(\.id))
        let unselected = allItems.filter { !selectedIDs.contains($0.id) }

        if query.isEmpty {
            notSelectedItems = unselected.sorted { $0.useAmount > $1.useAmount }
            return
        }

        let maxDistance = maxAllowedDistance(for: query.count)

        notSelectedItems = unselected.compactMap { item -> (item: Item, distance: Int, titleDistance: Int)? in
            let name = item.title.lowercased()
            let aliases = item.secondaryNames.map { $0.lowercased() }

            let titleDist = name.contains(query) ? 0 : name.levenshteinDistance(to: query)
            let aliasDist = aliases.contains(where: { $0.contains(query) }) ? 0 :
                (aliases.map { $0.levenshteinDistance(to: query) }.min() ?? Int.max)

            let bestDist = min(titleDist, aliasDist)

            if bestDist > maxDistance { return nil }

            return (item, bestDist, titleDist)
        }
        .sorted { lhs, rhs in
            switch sortingStrategy {
            case .pureUseAmount:
                if lhs.item.useAmount == rhs.item.useAmount {
                    return lhs.distance < rhs.distance
                }
                return lhs.item.useAmount > rhs.item.useAmount

            case .pureDistance:
                if lhs.distance == rhs.distance {
                    return lhs.item.useAmount > rhs.item.useAmount
                }
                return lhs.distance < rhs.distance

            case .mixed(let penaltyMultiplier):
                func score(for match: (item: Item, distance: Int, titleDistance: Int)) -> Double {
                    var divisor = Double(match.distance) + 1.0
                    if match.titleDistance > maxDistance {
                        divisor *= penaltyMultiplier
                    }
                    return (Double(match.item.useAmount) + 1.0) / divisor
                }
                return score(for: lhs) > score(for: rhs)
            }
        }
        .map { $0.item }
    }

    /// Selects an item if it is not already selected and invokes `onSelect`.
    public func selectItem(_ item: Item) {
        guard !selectedItems.contains(where: { $0.id == item.id }) else { return }

        withAnimation(.spring) {
            selectedItems.append(item)
            notSelectedItems.removeAll { $0.id == item.id }
        }
        onSelect?(item)
    }

    /// Removes an item from `selectedItems` and refreshes `notSelectedItems`.
    public func deselectItem(_ item: Item) {
        withAnimation(.spring) {
            selectedItems.removeAll { $0.id == item.id }
        }
        reapplySelectionFilter()
    }
}

/// A model that can be searched and picked from a keyboard accessory bar.
public protocol KeyboardPickableItem: Identifiable, Equatable {
    /// The primary display title shown on the suggestion chip and matched during search.
    var title: String { get }

    /// Optional alternate names or aliases matched during search (defaults to `[]`).
    var secondaryNames: [String] { get }

    /// Historical usage count used to prioritize frequently picked items (defaults to `0`).
    var useAmount: Int { get }
}

public extension KeyboardPickableItem {
    var secondaryNames: [String] { [] }

    var useAmount: Int { 0 }
}
