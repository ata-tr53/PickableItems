# PickableItems

A lightweight SwiftUI package that adds a searchable, fuzzy-matched keyboard accessory bar for picking tags, categories, assignees, or any custom model directly above the keyboard.

## Features

- **Type-scoped SwiftUI modifiers**: Attach multiple independent pickers (e.g., tags, categories, assignees) to the same `Form` or `View`.
- **Smart search & ranking**: Combines substring matching, length-scaled Levenshtein fuzzy search, alias support (`secondaryNames`), and usage frequency (`useAmount`).
- **Configurable sorting strategies**: Choose between `.mixed(penaltyMultiplier:)`, `.pureUseAmount`, and `.pureDistance`.
- **Optional leading & trailing accessories**: Add custom buttons, counters, or icons on either side of the suggestion bar.
- **Modern SwiftUI**: Built with `@Observable`, `@MainActor` isolation, and adaptive `.safeAreaBar` / `.glassProminent` support on OS 26+ with automatic fallbacks.

## Requirements

- iOS 18.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 6.4+

## Installation

Add `PickableItems` in Xcode via **File → Add Package Dependencies…**, or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ata-tr53/PickableItems.git", from: "1.0.0")
]
```

## Quick Start

### 1. Conform your model to `KeyboardPickableItem`

Only `id` and `title` are required; `secondaryNames` (`[]`) and `useAmount` (`0`) have default implementations.

```swift
import PickableItems

struct Tag: KeyboardPickableItem {
    let id = UUID()
    let title: String
    var secondaryNames: [String] = []
    var useAmount: Int = 0
}
```

### 2. Connect a coordinator to your view and `TextField`

```swift
import SwiftUI
import PickableItems

struct TagEditorView: View {
    @State private var query = ""
    @State private var coordinator = KeyboardPickableItemCoordinator<Tag>(
        allItems: [
            Tag(title: "SwiftUI", secondaryNames: ["ui"], useAmount: 20),
            Tag(title: "Observation", useAmount: 15),
            Tag(title: "Combine", useAmount: 5)
        ]
    )

    var body: some View {
        Form {
            TextField("Search tags...", text: $query)
                .keyboardItemPickerFocusBridge(
                    type: Tag.self,
                    text: $query,
                    clearOnSelect: true
                )

            ForEach(coordinator.selectedItems) { tag in
                Button(tag.title) {
                    coordinator.deselectItem(tag)
                }
            }
        }
        .keyboardItemPickerContainer(coordinator: coordinator) {
            Text("\(coordinator.selectedItems.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        } trailingAccessory: {
            Button {
                query = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .disabled(query.isEmpty)
        }
    }
}
```

## Sorting Strategies

Pass a `KeyboardPickableItemSortingStrategy` to `KeyboardPickableItemCoordinator` (or update `coordinator.sortingStrategy` at runtime):

- `.mixed(penaltyMultiplier: 2.0)` *(default)* — Balances `useAmount` and edit distance, applying a score divisor when a match only came from `secondaryNames`.
- `.pureUseAmount` — Orders strictly by highest `useAmount`, breaking ties by edit distance.
- `.pureDistance` — Orders strictly by closest text match, breaking ties by `useAmount`.

## License

MIT - See [LICENSE](LICENSE) for details.
