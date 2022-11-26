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
