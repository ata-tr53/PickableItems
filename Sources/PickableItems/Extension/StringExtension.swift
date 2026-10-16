//
//  StringExtension.swift
//  PickableItems
//
//  Created by İsmail Ata Bayraktutan on 8.09.2026.
//

internal extension String {
    func levenshteinDistance(to string: String) -> Int {
        if self.isEmpty { return string.count }
        if string.isEmpty { return self.count }
        
        let empty = [Int](repeating: 0, count: string.count + 1)
        var last = [Int](0...string.count)
        
        for (i, selfChar) in self.enumerated() {
            var current = [i + 1] + empty[1...]
            for (j, otherChar) in string.enumerated() {
                if selfChar == otherChar {
                    current[j + 1] = last[j]
                } else {
                    current[j + 1] = Swift.min(last[j], last[j + 1], current[j]) + 1
                }
            }
            last = current
        }
        return last.last!
    }
}
