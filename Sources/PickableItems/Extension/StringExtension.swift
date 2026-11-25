//
//  StringExtension.swift
//  PickableItems
//
//  Created by İsmail Ata Bayraktutan on 8.09.2026.
//

internal extension String {
    func levenshteinDistance(to other: String) -> Int {
        let lhs = Array(self)
        let rhs = Array(other)

        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previousRow = Array(0...rhs.count)
        var currentRow = [Int](repeating: 0, count: rhs.count + 1)

        for i in 0..<lhs.count {
            currentRow[0] = i + 1
            for j in 0..<rhs.count {
                if lhs[i] == rhs[j] {
                    currentRow[j + 1] = previousRow[j]
                } else {
                    currentRow[j + 1] = Swift.min(
                        previousRow[j],
                        previousRow[j + 1],
                        currentRow[j]
                    ) + 1
                }
            }
            swap(&previousRow, &currentRow)
        }

        return previousRow[rhs.count]
    }
}
