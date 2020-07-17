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

extension Optional where Wrapped == String {
    var _bound: String? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
    public var bound: String {
        get {
            return _bound ?? ""
        }
        set {
            _bound = newValue.isEmpty ? nil : newValue
        }
    }
}

extension LocalizedStringKey {
    var localizedString: String {
        let mirror = Mirror(reflecting: self)
        var key: String? = nil
        for property in mirror.children {
            if property.label == "key" {
                key = property.value as? String
            }
        }
        guard let goodKey = key else {
            logger.error("Failed to get localization key")
            return ""
        }
        return NSLocalizedString(goodKey, comment: "LocalizedStringKey")
    }
}

extension String: Error {
    
}

extension IndexSet: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

#if !os(macOS)
extension UIView {
    /// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
    /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
    func bindFrameToSuperviewBounds() {
        guard let superview = self.superview else {
            print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
            return
        }

        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true

    }
}
#endif

#if os(macOS)
enum FakeKeyboardType : Int {
    case asciiCapable
    case decimalPad
    case numberPad
}

struct EditButton {
    
}

extension View {
    func keyboardType(_ type: FakeKeyboardType) -> some View {
        return self
    }
    
    func navigationBarItems(trailing: EditButton) -> some View {
        return self
    }
}
#endif
