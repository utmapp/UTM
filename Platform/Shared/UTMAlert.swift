//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

/// Presents the legacy `Alert` for an optional `Identifiable` item.
///
/// This is `.alert(item:content:)` wrapped in a modifier whose stored properties the
/// unit tests can read, so a presented alert can be inspected. There is no behaviour
/// difference from calling `.alert(item:content:)` directly.
struct UTMAlertWithItemModifier<Item: Identifiable>: ViewModifier {
    let item: Binding<Item?>
    let popupBuilder: (Item) -> Alert
    /// Required by the inspection protocol; dismissal is not customizable here.
    var onDismiss: (() -> Void)? { nil }

    func body(content: Content) -> some View {
        content.alert(item: item, content: popupBuilder)
    }
}

extension View {
    /// Inspectable replacement for `.alert(item:content:)`.
    func utmAlert<Item: Identifiable>(item: Binding<Item?>, content: @escaping (Item) -> Alert) -> some View {
        modifier(UTMAlertWithItemModifier(item: item, popupBuilder: content))
    }
}
