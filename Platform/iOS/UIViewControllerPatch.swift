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

/// We need to set these when the VM starts running since there is no way to do it from SwiftUI right now
extension UIViewController {
    private static var _childForHomeIndicatorAutoHiddenStorage: [UIViewController: UIViewController?] = [:]
    
    @objc private dynamic var _childForHomeIndicatorAutoHidden: UIViewController? {
        Self._childForHomeIndicatorAutoHiddenStorage[self] ?? nil
    }
    
    @objc dynamic func setChildForHomeIndicatorAutoHidden(_ value: UIViewController?) {
        Self._childForHomeIndicatorAutoHiddenStorage[self] = value
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private static var _childViewControllerForPointerLockStorage: [UIViewController: UIViewController?] = [:]
    
    @objc private dynamic var _childViewControllerForPointerLock: UIViewController? {
        Self._childViewControllerForPointerLockStorage[self] ?? nil
    }
    
    @objc dynamic func setChildViewControllerForPointerLock(_ value: UIViewController?) {
        Self._childViewControllerForPointerLockStorage[self] = value
        setNeedsUpdateOfPrefersPointerLocked()
    }
    
    static func patch() {
        let originalChildForHomeIndicatorAutoHidden = #selector(getter: Self.childForHomeIndicatorAutoHidden)
        let swizzleChildForHomeIndicatorAutoHidden = #selector(getter: Self._childForHomeIndicatorAutoHidden)
        let originalChildForHomeIndicatorAutoHiddenMethod = class_getInstanceMethod(Self.self, originalChildForHomeIndicatorAutoHidden)!
        let swizzleChildForHomeIndicatorAutoHiddenMethod = class_getInstanceMethod(Self.self, swizzleChildForHomeIndicatorAutoHidden)!
        method_exchangeImplementations(originalChildForHomeIndicatorAutoHiddenMethod, swizzleChildForHomeIndicatorAutoHiddenMethod)
        let originalChildViewControllerForPointerLock = #selector(getter: Self.childViewControllerForPointerLock)
        let swizzleChildViewControllerForPointerLock = #selector(getter: Self._childViewControllerForPointerLock)
        let originalChildViewControllerForPointerLockMethod = class_getInstanceMethod(Self.self, originalChildViewControllerForPointerLock)!
        let swizzleChildViewControllerForPointerLockMethod = class_getInstanceMethod(Self.self, swizzleChildViewControllerForPointerLock)!
        method_exchangeImplementations(originalChildViewControllerForPointerLockMethod, swizzleChildViewControllerForPointerLockMethod)
    }
}
