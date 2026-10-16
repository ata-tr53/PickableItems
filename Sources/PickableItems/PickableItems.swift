
import SwiftUI

@Observable
public class KeyboardPickableItemCoordinator<Item: KeyboardPickableItem> {
    public var allItems: [Item]
    public var notSelectedItems: [Item]
    public var selectedItems: [Item]
    
    public var sortingStrategy: KeyboardPickableItemSortingStrategy
    
    internal var activeAccessoryID: UUID? = nil
    
    private var searchTask: Task<Void, Never>? = nil
    
    public init(
        allItems: [Item],
        notSelectedItems: [Item] = [],
        selectedItems: [Item],
        sortingStrategy: KeyboardPickableItemSortingStrategy = .mixed()
    ) {
        self.allItems = allItems
        self.notSelectedItems = notSelectedItems
        self.selectedItems = selectedItems
        self.sortingStrategy = sortingStrategy
    }
    
    public var isTextFieldFocused: Bool { activeAccessoryID != nil }
    
    @MainActor
    internal func updateNotSelectedItems(text: String, debounce: Bool = true) {
        searchTask?.cancel()
        
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
    
    @MainActor
    private func internalSearch(text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if query.isEmpty {
            notSelectedItems = allItems
                .filter { !selectedItems.contains($0) }
                .sorted { $0.useAmount > $1.useAmount }
            return
        }
        
        let unselected = allItems.filter { !selectedItems.contains($0) }
        
        notSelectedItems = unselected.compactMap { item -> (item: Item, distance: Int, titleDistance: Int)? in
            let name = item.title.lowercased()
            let aliases = item.secondaryNames.map { $0.lowercased() }
            
            // Calculate distances
            let titleDist = name.contains(query) ? 0 : name.levenshteinDistance(to: query)
            let aliasDist = aliases.contains(where: { $0.contains(query) }) ? 0 :
                (aliases.map { $0.levenshteinDistance(to: query) }.min() ?? Int.max)
            
            let bestDist = min(titleDist, aliasDist)
            
            if bestDist > 3 { return nil }
            
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
                    if match.titleDistance > 3 {
                        divisor *= penaltyMultiplier
                    }
                    return (Double(match.item.useAmount) + 1.0) / divisor
                }
                return score(for: lhs) > score(for: rhs)
            }
        }
        .map { $0.item }
    }
    
    @MainActor
    public func selectItem(_ item: Item) {
        guard !selectedItems.contains(item) else { return }
        
        withAnimation(.spring) {
            selectedItems.append(item)
        }
    }
    
    @MainActor
    public func deselectItem(_ item: Item) {
        withAnimation(.spring) {
            selectedItems.removeAll { $0.id == item.id }
        }
    }

}

public protocol KeyboardPickableItem: Identifiable, Comparable {
    var title: String { get }
    
    var secondaryNames: [String] { get }
    
    var useAmount: Int { get }
}

extension KeyboardPickableItem {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        return lhs.useAmount < rhs.useAmount
    }
}
