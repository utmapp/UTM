//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

// MARK: - View

@available(macOS 11, *)
public struct ToolbarTabView: View {
    let tabs: [AnyView]

    public init<Content: View>(@ViewBuilder content: () -> Content) {
        let views = content()
        self.tabs = [AnyView(views)]
    }
    
    public init<C0: View, C1: View>(@ViewBuilder content: () -> TupleView<(C0, C1)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1)]
    }
    
    public init<C0: View, C1: View, C2: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4, C5)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4), AnyView(views.5)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4, C5, C6)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4), AnyView(views.5), AnyView(views.6)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4), AnyView(views.5), AnyView(views.6), AnyView(views.7)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4), AnyView(views.5), AnyView(views.6), AnyView(views.7), AnyView(views.8)]
    }
    
    public init<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(@ViewBuilder content: () -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)>) {
        let views = content().value
        self.tabs = [AnyView(views.0), AnyView(views.1), AnyView(views.2), AnyView(views.3), AnyView(views.4), AnyView(views.5), AnyView(views.6), AnyView(views.7), AnyView(views.8), AnyView(views.9)]
    }
    
    public var body: some View {
        let nsTabs = tabs.map { (content) -> NSTabViewItem in
            var tabViewItem: NSTabViewItem? = nil
            let view = content.onPreferenceChange(ToolbarTabItemPreferenceKey.self) { (value: ToolbarTabItemPreference) in
                guard let item = tabViewItem else {
                    logger.error("Failed to update \(value.label.localizedString) since item is nil!")
                    return
                }
                item.label = value.label.localizedString
                if value.nsImage != nil {
                    item.image = value.nsImage!
                }
                if value.tooltip != nil {
                    item.toolTip = value.tooltip!.localizedString
                }
            }
            tabViewItem = NSTabViewItem(viewController: NSHostingController(rootView: view))
            tabViewItem!.label = "" // FIXME: bypass lazy loading of label
            return tabViewItem!
        }
        return ToolbarTabViewController(tabViewItems: nsTabs)
    }
}

// MARK: - Tab Item Preference

@available(macOS 11, *)
private struct ToolbarTabItemPreference : Equatable {
    let label: LocalizedStringKey
    let nsImage: NSImage?
    let tooltip: LocalizedStringKey?
    
    static let none = ToolbarTabItemPreference(label: "", nsImage: nil, tooltip: nil)
    
    init(label: LocalizedStringKey, nsImage: NSImage?, tooltip: LocalizedStringKey?) {
        self.label = label
        self.nsImage = nsImage
        self.tooltip = tooltip
    }
    
    static func == (lhs: ToolbarTabItemPreference, rhs: ToolbarTabItemPreference) -> Bool {
        lhs.label == rhs.label && lhs.nsImage == rhs.nsImage
    }
}

private struct ToolbarTabItemPreferenceKey: PreferenceKey {
    static var defaultValue: ToolbarTabItemPreference = .none

    static func reduce(value: inout ToolbarTabItemPreference, nextValue: () -> ToolbarTabItemPreference) {
        value = nextValue()
    }
}

// MARK: - Toolbar item modifier

@available(macOS 11, *)
extension View {
    func toolbarTabItem(_ label: LocalizedStringKey, nsImage: NSImage? = nil, tooltip: LocalizedStringKey? = nil) -> some View {
        self.preference(key: ToolbarTabItemPreferenceKey.self, value: ToolbarTabItemPreference(label: label, nsImage: nsImage, tooltip: tooltip))
    }
    
    func toolbarTabItem(_ label: LocalizedStringKey, systemImage: String, tooltip: LocalizedStringKey? = nil) -> some View {
        self.preference(key: ToolbarTabItemPreferenceKey.self, value: ToolbarTabItemPreference(label: label, nsImage: NSImage(systemSymbolName: systemImage, accessibilityDescription: "\(tooltip ?? "")"), tooltip: tooltip))
    }
}

// MARK: - Preview

@available(macOS 11, *)
struct ToolbarTabView_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarTabView {
            Text("The First Tab")
                .toolbarTabItem("First", systemImage: "1.square.fill", tooltip: "First one")
            Text("Another Tab")
                .toolbarTabItem("Second", systemImage: "2.square.fill", tooltip: "Second one")
            Text("The Last Tab")
                .toolbarTabItem("Third", systemImage: "3.square.fill", tooltip: "Third one")
        }
    }
}
