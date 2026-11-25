import SwiftUI

/// Coordinates filtering, ranking, selection, and keyboard accessory visibility for a specific `KeyboardPickableItem` type.
@MainActor
@Observable
public class KeyboardPickableItemCoordinator<Item: KeyboardPickableItem> {
    /// The complete list of items available to pick from. Updating this refreshes `notSelectedItems`.
    public var allItems: [Item] {
        didSet { internalSearch(text: lastQuery) }
    }

    /// The currently filtered and ranked items that have not yet been selected.
    public private(set) var notSelectedItems: [Item]

    /// The items currently selected by the user.
    public var selectedItems: [Item]

    /// The ranking strategy used to order search results. Updating this re-ranks `notSelectedItems`.
    public var sortingStrategy: KeyboardPickableItemSortingStrategy {
        didSet { internalSearch(text: lastQuery) }
    }

    /// Optional callback invoked immediately after an item is selected.
    public var onSelect: ((Item) -> Void)?

    internal var activeAccessoryID: UUID? = nil

    private var searchTask: Task<Void, Never>? = nil
    private var lastQuery: String = ""

    /// Creates a new coordinator for the given items.
    /// - Parameters:
    ///   - allItems: The full pool of pickable items.
    ///   - selectedItems: Initially selected items (defaults to empty).
    ///   - sortingStrategy: Strategy used to rank matching items (defaults to `.mixed()`).
    ///   - onSelect: Optional callback invoked whenever an item is selected.
    public init(
        allItems: [Item],
        selectedItems: [Item] = [],
        sortingStrategy: KeyboardPickableItemSortingStrategy = .mixed(),
        onSelect: ((Item) -> Void)? = nil
    ) {
        self.allItems = allItems
        self.selectedItems = selectedItems
        self.sortingStrategy = sortingStrategy
        self.onSelect = onSelect

        let selectedIDs = Set(selectedItems.map(\.id))
        self.notSelectedItems = allItems
            .filter { !selectedIDs.contains($0.id) }
            .sorted { $0.useAmount > $1.useAmount }
    }

    /// Returns `true` when any `TextField` bridged to this coordinator is currently focused.
    public var isTextFieldFocused: Bool { activeAccessoryID != nil }

    internal func updateNotSelectedItems(text: String, debounce: Bool = true) {
        searchTask?.cancel()
        lastQuery = text

        if !debounce {
            internalSearch(text: text)
            return
        }

        searchTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.internalSearch(text: text)
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

    private func internalSearch(text: String) {
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
        internalSearch(text: lastQuery)
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
