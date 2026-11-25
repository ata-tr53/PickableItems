//
//  KeyboardAccessory.swift
//  PickableItems
//
//  Created by İsmail Ata Bayraktutan on 8.09.2026.
//

import SwiftUI

internal struct KeyboardAccessoryViewModifier<
    Item: KeyboardPickableItem,
    LeadingAccessory: View,
    TrailingAccessory: View
>: ViewModifier {
    @Environment(KeyboardPickableItemCoordinator<Item>.self) private var coordinator

    let leadingAccessory: () -> LeadingAccessory
    let trailingAccessory: () -> TrailingAccessory

    func body(content: Content) -> some View {
        if #available(anyAppleOS 26.0, *) {
            content
                .safeAreaBar(edge: .bottom) {
                    if coordinator.activeAccessoryID != nil {
                        mainView
                    }
                }
        } else {
            content
                .safeAreaInset(edge: .bottom) {
                    if coordinator.activeAccessoryID != nil {
                        mainView
                    }
                }
        }
    }

    @ViewBuilder
    private var mainView: some View {
        HStack(spacing: 0) {
            if LeadingAccessory.self != EmptyView.self {
                leadingAccessory()
                    .padding(.leading)
            }

            keyboardAccessoryView
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.02),
                            .init(color: .black, location: 0.98),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ).ignoresSafeArea()
                }

            if TrailingAccessory.self != EmptyView.self {
                trailingAccessory()
                    .padding(.trailing)
            }
        }.padding(.bottom)
    }

    @ViewBuilder
    private var keyboardAccessoryView: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(coordinator.notSelectedItems) { item in
                    if #available(anyAppleOS 26.0, *) {
                        keyboardItemButton(for: item)
                            .buttonStyle(.glassProminent)
                    } else {
                        keyboardItemButton(for: item)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }.padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.spring, value: coordinator.notSelectedItems)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func keyboardItemButton(for item: Item) -> some View {
        Button {
            coordinator.selectItem(item)
        } label: { Label(item.title, systemImage: "plus").font(.callout.bold()) }
    }
}

internal struct KeyboardAccessoryTextFieldModifier<Item: KeyboardPickableItem>: ViewModifier {
    @Environment(KeyboardPickableItemCoordinator<Item>.self) private var coordinator
    @FocusState private var isFocused: Bool

    @Binding var text: String
    let clearOnSelect: Bool

    @State private var viewID: UUID = UUID()

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    coordinator.activeAccessoryID = viewID
                    coordinator.updateNotSelectedItems(text: text, debounce: false)
                } else {
                    if coordinator.activeAccessoryID == viewID {
                        coordinator.activeAccessoryID = nil
                    }
                }
            }
            .onChange(of: coordinator.selectedItems) { oldValue, newValue in
                guard isFocused else { return }
                if clearOnSelect && newValue.count > oldValue.count {
                    text = ""
                    coordinator.updateNotSelectedItems(text: "", debounce: false)
                } else {
                    coordinator.updateNotSelectedItems(text: text, debounce: false)
                }
            }
            .onChange(of: text) { _, newValue in
                guard isFocused else { return }
                coordinator.updateNotSelectedItems(text: newValue)
            }
    }
}


public extension View {
    /// Attaches a keyboard accessory bar for picking items managed by `coordinator`, with both leading and trailing accessory views.
    func keyboardItemPickerContainer<
        Item: KeyboardPickableItem,
        LeadingAccessory: View,
        TrailingAccessory: View
    >(
        coordinator: KeyboardPickableItemCoordinator<Item>,
        @ViewBuilder leadingAccessory: @escaping (() -> LeadingAccessory),
        @ViewBuilder trailingAccessory: @escaping (() -> TrailingAccessory)
    ) -> some View {
        self
            .modifier(KeyboardAccessoryViewModifier<Item, LeadingAccessory, TrailingAccessory>(
                leadingAccessory: leadingAccessory, trailingAccessory: trailingAccessory
            ))
            .environment(coordinator)
    }

    /// Attaches a keyboard accessory bar for picking items managed by `coordinator`, with a leading accessory view.
    func keyboardItemPickerContainer<
        Item: KeyboardPickableItem,
        LeadingAccessory: View
    >(
        coordinator: KeyboardPickableItemCoordinator<Item>,
        @ViewBuilder leadingAccessory: @escaping (() -> LeadingAccessory)
    ) -> some View {
        self
            .modifier(KeyboardAccessoryViewModifier<Item, LeadingAccessory, EmptyView>(
                leadingAccessory: leadingAccessory, trailingAccessory: { EmptyView() }
            ))
            .environment(coordinator)
    }

    /// Attaches a keyboard accessory bar for picking items managed by `coordinator`, with a trailing accessory view.
    func keyboardItemPickerContainer<
        Item: KeyboardPickableItem,
        TrailingAccessory: View
    >(
        coordinator: KeyboardPickableItemCoordinator<Item>,
        @ViewBuilder trailingAccessory: @escaping (() -> TrailingAccessory)
    ) -> some View {
        self
            .modifier(KeyboardAccessoryViewModifier<Item, EmptyView, TrailingAccessory>(
                leadingAccessory: { EmptyView() }, trailingAccessory: trailingAccessory
            ))
            .environment(coordinator)
    }

    /// Attaches a keyboard accessory bar for picking items managed by `coordinator`.
    func keyboardItemPickerContainer<Item: KeyboardPickableItem>(
        coordinator: KeyboardPickableItemCoordinator<Item>
    ) -> some View {
        self
            .modifier(KeyboardAccessoryViewModifier<Item, EmptyView, EmptyView>(
                leadingAccessory: { EmptyView() },
                trailingAccessory: { EmptyView() }
            ))
            .environment(coordinator)
    }

    /// Connects a `TextField` to the nearest `keyboardItemPickerContainer` matching `type`.
    /// - Parameters:
    ///   - type: The `KeyboardPickableItem` type managed by the target coordinator.
    ///   - text: Binding to the text field's query string.
    ///   - clearOnSelect: When `true`, clears `text` automatically after the user taps a suggestion chip.
    func keyboardItemPickerFocusBridge<Item: KeyboardPickableItem>(
        type: Item.Type,
        text: Binding<String>,
        clearOnSelect: Bool = false
    ) -> some View {
        self.modifier(KeyboardAccessoryTextFieldModifier<Item>(text: text, clearOnSelect: clearOnSelect))
    }
}
