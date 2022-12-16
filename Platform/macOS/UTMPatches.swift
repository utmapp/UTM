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

import Foundation

/// Handles Obj-C patches to fix AppKit issues
final class UTMPatches {
    static private var isPatched: Bool = false
    
    /// Installs the patches
    /// TODO: Some thread safety/race issues etc
    static func patchAll() {
        NSKeyedUnarchiver.patchToolbarItem()
        NSApplication.patchApplicationScripting()
        // SwiftUI bug: works around crash due to "already had more Update Constraints in Window passes than there are views in the window" exception
        UserDefaults.standard.set(false, forKey: "NSWindowAssertWhenDisplayCycleLimitReached")
    }
}

fileprivate extension NSObject {
    static func patch(_ original: Selector, with swizzle: Selector, class cls: AnyClass?) {
        let originalMethod = class_getInstanceMethod(cls, original)!
        let swizzleMethod = class_getInstanceMethod(cls, swizzle)!
        method_exchangeImplementations(originalMethod, swizzleMethod)
    }
}

/// Patch unarchiving XIB objeccts
extension NSKeyedUnarchiver {
    @objc dynamic func xxx_decodeObject(forKey key: String) -> Any? {
        switch key {
        case "NSMenuToolbarItemImage": return xxx_decodeObject(forKey: "NSToolbarItemImage")
        case "NSMenuToolbarItemTitle": return xxx_decodeObject(forKey: "NSToolbarItemTitle")
        case "NSMenuToolbarItemTarget": return xxx_decodeObject(forKey: "NSToolbarItemTarget")
        case "NSMenuToolbarItemAction": return xxx_decodeObject(forKey: "NSToolbarItemAction")
        default: return xxx_decodeObject(forKey: key)
        }
    }
    
    /// Workaround for exception when creating NSMenuToolbarItem from XIB
    fileprivate static func patchToolbarItem() {
        patch(#selector(Self.decodeObject(forKey:)),
              with: #selector(Self.xxx_decodeObject(forKey:)),
              class: Self.self)
    }
}

private var ScriptingDelegateHandle: Int = 0

/// Patch NSApplication to use a new delegate for scripting tasks
/// We cannot use NSApplicationDelegate because SwiftUI wraps it with its own implementation
extension NSApplication {
    /// Set this, at startup, to the delegate used for scripting
    weak var scriptingDelegate: NSApplicationDelegate? {
        set {
            objc_setAssociatedObject(self, &ScriptingDelegateHandle, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            objc_getAssociatedObject(self, &ScriptingDelegateHandle) as? NSApplicationDelegate
        }
    }
    
    /// Get KVO value from scripting delegate if implemented
    /// - Parameter key: Key to look up
    /// - Returns: Value from either scripting delegate or the default implementation
    @objc dynamic func xxx_value(forKey key: String) -> Any? {
        if scriptingDelegate?.application?(self, delegateHandlesKey: key) ?? false {
            return (scriptingDelegate as! NSObject).value(forKey: key)
        } else {
            return xxx_value(forKey: key)
        }
    }
    
    /// Set KVO value in scripting delegate if implemented
    /// - Parameters:
    ///   - value: Value to set to
    ///   - key: Key to look up
    @objc dynamic func xxx_setValue(_ value: Any?, forKey key: String) {
        if scriptingDelegate?.application?(self, delegateHandlesKey: key) ?? false {
            return (scriptingDelegate as! NSObject).setValue(value, forKey: key)
        } else {
            return xxx_setValue(value, forKey: key)
        }
    }
    
    /// Get KVO value from scripting delegate if implemented
    /// - Parameters:
    ///   - index: Index of item
    ///   - key: Key to look up
    /// - Returns: Value from either scripting delegate or the default implementation
    @objc dynamic func xxx_value(at index: Int, inPropertyWithKey key: String) -> Any? {
        if scriptingDelegate?.application?(self, delegateHandlesKey: key) ?? false {
            return (scriptingDelegate as! NSObject).value(at: index, inPropertyWithKey: key)
        } else {
            return xxx_value(at: index, inPropertyWithKey: key)
        }
    }
    
    /// Set KVO value in scripting delegate if implemented
    /// - Parameters:
    ///   - index: Index of item
    ///   - key: Key to look up
    ///   - value: Value to set item to
    @objc dynamic func xxx_replaceValue(at index: Int, inPropertyWithKey key: String, withValue value: Any) {
        if scriptingDelegate?.application?(self, delegateHandlesKey: key) ?? false {
            return (scriptingDelegate as! NSObject).replaceValue(at: index, inPropertyWithKey: key, withValue: value)
        } else {
            return xxx_replaceValue(at: index, inPropertyWithKey: key, withValue: value)
        }
    }
    
    fileprivate static func patchApplicationScripting() {
        patch(#selector(Self.value(forKey:)),
              with: #selector(Self.xxx_value(forKey:)),
              class: Self.self)
        patch(#selector(Self.value(at:inPropertyWithKey:)),
              with: #selector(Self.xxx_value(at:inPropertyWithKey:)),
              class: Self.self)
        patch(#selector(Self.setValue(_:forKey:)),
              with: #selector(Self.xxx_setValue(_:forKey:)),
              class: Self.self)
        patch(#selector(Self.replaceValue(at:inPropertyWithKey:withValue:)),
              with: #selector(Self.xxx_replaceValue(at:inPropertyWithKey:withValue:)),
              class: Self.self)
    }
}
