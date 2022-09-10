//
// Copyright © 2022 osy. All rights reserved.
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

import UIKit

/// Handles Obj-C patches to fix SwiftUI issues
final class UTMViewControllerPatches {
    static private var isPatched: Bool = false
    
    /// Installs the patches
    /// TODO: Some thread safety/race issues etc
    static func patchAll() {
        UIViewController.patchViewController()
        UIResponder.patchResponder()
    }
}

fileprivate extension NSObject {
    static func patch(_ original: Selector, with swizzle: Selector, class cls: AnyClass?) {
        let originalMethod = class_getInstanceMethod(cls, original)!
        let swizzleMethod = class_getInstanceMethod(cls, swizzle)!
        method_exchangeImplementations(originalMethod, swizzleMethod)
    }
}

/// We need to set these when the VM starts running since there is no way to do it from SwiftUI right now
extension UIViewController {
    private static var _childForHomeIndicatorAutoHiddenStorage: [UIViewController: UIViewController] = [:]
    
    @objc private dynamic var _childForHomeIndicatorAutoHidden: UIViewController? {
        Self._childForHomeIndicatorAutoHiddenStorage[self]
    }
    
    @objc dynamic func setChildForHomeIndicatorAutoHidden(_ value: UIViewController?) {
        if let value = value {
            Self._childForHomeIndicatorAutoHiddenStorage[self] = value
        } else {
            Self._childForHomeIndicatorAutoHiddenStorage.removeValue(forKey: self)
        }
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private static var _childViewControllerForPointerLockStorage: [UIViewController: UIViewController] = [:]
    
    @objc private dynamic var _childViewControllerForPointerLock: UIViewController? {
        Self._childViewControllerForPointerLockStorage[self]
    }
    
    @objc dynamic func setChildViewControllerForPointerLock(_ value: UIViewController?) {
        if let value = value {
            Self._childViewControllerForPointerLockStorage[self] = value
        } else {
            Self._childViewControllerForPointerLockStorage.removeValue(forKey: self)
        }
        setNeedsUpdateOfPrefersPointerLocked()
    }
    
    /// SwiftUI currently does not provide a way to set the View Conrtoller's home indicator or pointer lock
    fileprivate static func patchViewController() {
        patch(#selector(getter: Self.childForHomeIndicatorAutoHidden),
              with: #selector(getter: Self._childForHomeIndicatorAutoHidden),
              class: Self.self)
        patch(#selector(getter: Self.childViewControllerForPointerLock),
              with: #selector(getter: Self._childViewControllerForPointerLock),
              class: Self.self)
    }
}

extension UIResponder {
    private static var _pressesOverride: [UIResponder: UIResponder] = [:]
    
    @objc private dynamic func _pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let override = Self._pressesOverride[self] {
            override.pressesBegan(presses, with: event)
        } else if let next = self.next, let override = Self._pressesOverride[next] {
            override.pressesBegan(presses, with: event)
        } else {
            _pressesBegan(presses, with: event)
        }
    }
    
    @objc private dynamic func _pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let override = Self._pressesOverride[self] {
            override.pressesEnded(presses, with: event)
        } else if let next = self.next, let override = Self._pressesOverride[next] {
            override.pressesEnded(presses, with: event)
        } else {
            _pressesEnded(presses, with: event)
        }
    }
    
    @objc func setChildForPressesHandler(_ value: UIResponder?) {
        if let value = value {
            Self._pressesOverride[self] = value
        } else {
            Self._pressesOverride.removeValue(forKey: self)
        }
    }
    
    /// A view controller inside SwiftUI may not receive press events.
    fileprivate static func patchResponder() {
        patch(#selector(Self.pressesBegan(_:with:)),
              with: #selector(Self._pressesBegan(_:with:)),
              class: Self.self)
        patch(#selector(Self.pressesEnded(_:with:)),
              with: #selector(Self._pressesEnded(_:with:)),
              class: Self.self)
    }
}
