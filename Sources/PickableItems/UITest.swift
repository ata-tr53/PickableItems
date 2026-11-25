//
//  UITest.swift
//  PickableItems
//
//  Created by İsmail Ata Bayraktutan on 8.09.2026.
//

#if DEBUG
import SwiftUI

private struct UITest: View {
    // MARK: - States for TextFields
    @State private var tagText: String = ""
    @State private var categoryText: String = ""
    @State private var assigneeText: String = ""

    // MARK: - Coordinators
    @State private var tagCoordinator = KeyboardPickableItemCoordinator<TestTag>(
        allItems: [
            TestTag(title: "SwiftUI", useAmount: 20),
            TestTag(title: "Observation", useAmount: 15),
            TestTag(title: "Combine", useAmount: 5)
        ],
        selectedItems: []
    )

    @State private var categoryCoordinator = KeyboardPickableItemCoordinator<TestCategory>(
        allItems: [
            TestCategory(title: "Work", useAmount: 50),
            TestCategory(title: "Personal", useAmount: 30),
            TestCategory(title: "Urgent", useAmount: 10)
        ],
        selectedItems: []
    )

    @State private var assigneeCoordinator = KeyboardPickableItemCoordinator<TestAssignee>(
        allItems: [
            TestAssignee(title: "Alice", useAmount: 5),
            TestAssignee(title: "Bob", useAmount: 2),
            TestAssignee(title: "Charlie", useAmount: 8)
        ],
        selectedItems: []
    )

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Tags
                Section {
                    TextField("Search tags...", text: $tagText)
                        .keyboardItemPickerFocusBridge(type: TestTag.self, text: $tagText, clearOnSelect: true)

                    if !tagCoordinator.selectedItems.isEmpty {
                        SelectedItemsView(items: tagCoordinator.selectedItems) { item in
                            tagCoordinator.deselectItem(item)
                        }
                    }
                } header: {
                    Text("Tags")
                }

                // MARK: - Section 2: Categories
                Section {
                    TextField("Search categories...", text: $categoryText)
                        .keyboardItemPickerFocusBridge(type: TestCategory.self, text: $categoryText)

                    if !categoryCoordinator.selectedItems.isEmpty {
                        SelectedItemsView(items: categoryCoordinator.selectedItems) { item in
                            categoryCoordinator.deselectItem(item)
                        }
                    }
                } header: {
                    Text("Categories")
                }

                // MARK: - Section 3: Assignees
                Section {
                    TextField("Search assignees...", text: $assigneeText)
                        .keyboardItemPickerFocusBridge(type: TestAssignee.self, text: $assigneeText)

                    if !assigneeCoordinator.selectedItems.isEmpty {
                        SelectedItemsView(items: assigneeCoordinator.selectedItems) { item in
                            assigneeCoordinator.deselectItem(item)
                        }
                    }
                } header: {
                    Text("Assignees")
                }
            }
            .navigationTitle("Task Details")

            // MARK: - Container Modifiers

            // 1. Tags with dynamic text and a clear button
            .keyboardItemPickerContainer(coordinator: tagCoordinator) {
                Text("\(tagCoordinator.selectedItems.count) Selected")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 70)
            } trailingAccessory: {
                Button {
                    tagText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.large)
                }
                .disabled(tagText.isEmpty)
            }

            // 2. Categories with an icon and an Add button
            .keyboardItemPickerContainer(coordinator: categoryCoordinator) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue.gradient)
                    .padding(.trailing, 4)
            } trailingAccessory: {
                Button("New") {
                    print("Present Add New Category Sheet")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.blue)
            }

            // 3. Assignees using the default extension (No accessories)
            .keyboardItemPickerContainer(coordinator: assigneeCoordinator)
        }
    }
}

// MARK: - Reusable View for Selected Items
private struct SelectedItemsView<Item: KeyboardPickableItem>: View {
    var items: [Item]
    var onRemove: (Item) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(items) { item in
                    Button {
                        onRemove(item)
                    } label: {
                        HStack {
                            Text(item.title)
                            Image(systemName: "xmark.circle.fill")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    }
                }
            }
        }
        .animation(.spring, value: items)
    }
}

// MARK: - Data Models
private struct TestTag: KeyboardPickableItem {
    let id = UUID()
    let title: String
    var secondaryNames: [String] = []
    var useAmount: Int = 0
}

private struct TestCategory: KeyboardPickableItem {
    let id = UUID()
    let title: String
    var secondaryNames: [String] = []
    var useAmount: Int = 0
}

private struct TestAssignee: KeyboardPickableItem {
    let id = UUID()
    let title: String
    var secondaryNames: [String] = []
    var useAmount: Int = 0
}

#Preview {
    UITest()
        .frame(minWidth: 300, minHeight: 500)
}
#endif
