//
//  KeyboardPickableItemSortingStrategy.swift
//  PickableItems
//
//  Created by İsmail Ata Bayraktutan on 8.09.2026.
//


public enum KeyboardPickableItemSortingStrategy {
    /// Strictly prioritizes historical usage. Falls back to distance for ties.
    case pureUseAmount
    
    /// Strictly prioritizes text accuracy (Levenshtein distance). Falls back to usage for ties.
    case pureDistance
    
    /// Balances usage and distance. 
    /// - Parameter penaltyMultiplier: How much to divide the final score by if the match was only found via a secondary name (default is 2.0).
    case mixed(penaltyMultiplier: Double = 2.0)
}
