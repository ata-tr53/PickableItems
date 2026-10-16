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
            leadingAccessory()
                .padding(.leading)
            
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
            
            trailingAccessory()
                .padding(.trailing)
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
    
    @State private var viewID: UUID = UUID()
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    coordinator.activeAccessoryID = viewID
                    coordinator.updateNotSelectedItems(text: text)
                } else {
                    if coordinator.activeAccessoryID == viewID {
                        coordinator.activeAccessoryID = nil
                    }
                }
            }
            
            .onChange(of: coordinator.selectedItems) { _, _ in
                if isFocused {
                    coordinator.updateNotSelectedItems(text: text, debounce: false)
                }
            }

            .onChange(of: text) { _, newValue in
                coordinator.updateNotSelectedItems(text: newValue)
            }
    }
}


public extension View {
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
    
    func keyboardItemPickerFocusBridge<Item: KeyboardPickableItem>(type: Item.Type, text: Binding<String>) -> some View {
        self.modifier(KeyboardAccessoryTextFieldModifier<Item>(text: text))
    }
}
