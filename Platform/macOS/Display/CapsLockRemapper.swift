//
// Copyright © 2026 UTM contributors. All rights reserved.
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
import Carbon.HIToolbox
import IOKit.hid
import IOKit.hidsystem

/// Temporarily turns Caps Lock into an ordinary key while VM input is captured.
///
/// macOS treats Caps Lock as a locking modifier and never delivers its physical release, so a
/// guest that uses it as a held modifier (e.g. a screen reader) never sees it let go. Remapping
/// it to F20 at the HID layer (Apple TN2450) makes macOS deliver a normal down/up pair, which
/// `VMMetalView` translates back to the Caps Lock scan code. F20 is the highest function key
/// macOS delivers and is not on any Apple keyboard, so no real key is shadowed. The remap
/// cannot outlive a reboot or the keyboard being unplugged.
@MainActor
final class CapsLockRemapper {
    static let shared = CapsLockRemapper()

    /// Key code macOS delivers for the remapped Caps Lock.
    static let hostKeyCode = kVK_F20

    private static let capsLockUsage = usage(kHIDUsage_KeyboardCapsLock)
    private static let f20Usage = usage(kHIDUsage_KeyboardF20)
    private static let remap: [String: UInt64] = [kIOHIDKeyboardModifierMappingSrcKey: capsLockUsage,
                                                  kIOHIDKeyboardModifierMappingDstKey: f20Usage]

    private lazy var client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    /// Each remapped keyboard with the mapping it had before.
    private var originals: [(keyboard: IOHIDServiceClient, mapping: [[String: Any]])] = []

    var isActive: Bool {
        !originals.isEmpty
    }

    private init() {
    }

    /// Remaps Caps Lock on every attached keyboard, or does nothing if already remapped.
    func apply() {
        guard !isActive else {
            return
        }
        for keyboard in keyboards {
            let original = IOHIDServiceClientCopyProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString) as? [[String: Any]] ?? []
            let remapped = original.filter { !Self.isCapsLock($0) } + [Self.remap]
            guard IOHIDServiceClientSetProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString, remapped as CFArray) else {
                continue
            }
            originals.append((keyboard, original))
        }
        logger.debug("remapped Caps Lock on \(originals.count) keyboard(s)")
    }

    /// Puts back each keyboard's previous mapping, or does nothing if not remapped.
    func restore() {
        for (keyboard, mapping) in originals {
            IOHIDServiceClientSetProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString, mapping as CFArray)
        }
        originals = []
    }

    /// If UTM died while remapped, strips the remap so the host's Caps Lock works again.
    /// The previous mapping died with the process, so only the Caps Lock → F20 entry is
    /// removed; a user's own identical mapping cannot be told apart and is removed too.
    func recoverAtLaunch() {
        for keyboard in keyboards {
            guard let current = IOHIDServiceClientCopyProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString) as? [[String: Any]],
                  current.contains(where: Self.isRemap) else {
                continue
            }
            IOHIDServiceClientSetProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString, current.filter { !Self.isRemap($0) } as CFArray)
            logger.debug("removed stale Caps Lock remap")
        }
    }

    /// Packs a keyboard usage the way `UserKeyMapping` expects it: page in the high word, usage in the low.
    private static func usage(_ usage: Int) -> UInt64 {
        UInt64(kHIDPage_KeyboardOrKeypad) << 32 | UInt64(usage)
    }

    private var keyboards: [IOHIDServiceClient] {
        let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return services.filter { IOHIDServiceClientConformsTo($0, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0 }
    }

    private static func isCapsLock(_ entry: [String: Any]) -> Bool {
        entry[kIOHIDKeyboardModifierMappingSrcKey] as? UInt64 == capsLockUsage
    }

    private static func isRemap(_ entry: [String: Any]) -> Bool {
        isCapsLock(entry) && entry[kIOHIDKeyboardModifierMappingDstKey] as? UInt64 == f20Usage
    }
}
