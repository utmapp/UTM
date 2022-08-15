//
// Copyright © 2021 osy. All rights reserved.
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

/// Based on https://stackoverflow.com/a/64344453/4236245
/// Translated to Swift by conath
class KeyCodeMap {
    private static var keyMapDict: Dictionary<String, Dictionary<String, Int>>!
    private static var modFlagDict: Dictionary<String, UInt>!
    private static var modFlags: [UInt]!
    
    /// Creates the internal key map if needed. Must be called on the main queue!
    static func createKeyMapIfNeeded() {
        if keyMapDict == nil {
            keyMapDict = makeKeyMap()
        }
    }
    
    static func characterToKeyCode(character: Character) -> Dictionary<String, Int>? {
        createKeyMapIfNeeded()
        
        /*
         The returned dictionary contains entries for the virtual key code and boolean flags
         for modifier keys used for the character.
         */
        if let keyCodeDict = keyMapDict[String(character)] {
            return keyCodeDict
        } else {
            return tryHandleSpecialChar(character)
        }
    }
    
    private static func makeKeyMap() -> Dictionary<String, Dictionary<String, Int>> {
        var modifiers: UInt = 0
        
        // create dictionary of modifier names and keys.
        if (modFlagDict == nil) {
            modFlagDict = ["option":    NSEvent.ModifierFlags.option.rawValue,
                           "shift":     NSEvent.ModifierFlags.shift.rawValue,
                           "function":  NSEvent.ModifierFlags.function.rawValue,
                           "control":   NSEvent.ModifierFlags.control.rawValue,
                           "command":   NSEvent.ModifierFlags.command.rawValue]
            modFlags = Array(modFlagDict.values)
        }
        var keyMapDict = Dictionary<String, Dictionary<String, Int>>()
        
        // run through 128 base key codes to see what they produce
        for keyCode: UInt16 in 0..<128 {
            // create dummy NSEvent from a CGEvent for a keypress
            let coreEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
            let keyEvent = NSEvent(cgEvent: coreEvent)!
            
            if (keyEvent.type == .keyDown) {
                // this repeat/while loop through every permutation of modifier keys for a given key code
                repeat {
                    var subDict = Dictionary<String, Int>()
                    // cerate dictionary containing current modifier keys and virtual key code
                    for key: String in modFlagDict.keys {
                        let modKeyIsUsed = ((modFlagDict[key]! & modifiers) != 0)
                        subDict[key] = NSNumber(booleanLiteral: modKeyIsUsed).intValue
                    }
                    subDict["virtKeyCode"] = (keyCode as NSNumber).intValue
                    
                    // manipulate the NSEvent to get character produce by virtual key code and modifiers
                    var character: String
                    if modifiers == 0 {
                        character = keyEvent.characters!
                    } else {
                        character = keyEvent.characters(byApplyingModifiers: NSEvent.ModifierFlags(rawValue: modifiers))!
                    }
                    
                    // add sub-dictionary to main dictionary using character as key
                    if keyMapDict[character] == nil {
                        keyMapDict[character] = subDict
                    }
                    
                    // permutate the modifiers
                    modifiers = permutatateMods(modFlags: modFlags)
                } while (modifiers != 0)
            }
        }
        
        return keyMapDict
    }
    
    private static let idxSet = NSMutableIndexSet()
    
    private static func permutatateMods(modFlags: [UInt]) -> UInt {
        var modifiers: UInt = 0
        var idx: Int = 0
        
        /*
         Starting at 0, if the index exists, remove it and move up; if the index doesn't exist, add it. Will
         cycle through a standard binary progression. Indexes are then applied to the passed array, and the
         selected elements are 'OR'ed together
         */
        var done = false
        while !done {
            if idxSet.contains([idx]) {
                idxSet.remove([idx])
                idx += 1
                continue;
            }
            if idx < modFlags.count {
                idxSet.add([idx])
            } else {
                idxSet.removeAllIndexes()
            }
            done = true
        }
        
        let modArray = (modFlags as NSArray).objects(at: idxSet as IndexSet) as NSArray
        
        for modObj in modArray {
            modifiers |= (modObj as! NSNumber).uintValue
        }
        
        return modifiers
    }
    
    /// Keyboard scan code for key down and up (which is usually `down + 0x80`)
    struct ScanCodes {
        let down: UInt16
        let up: UInt8
        
        /// Construct a `ScanCodes` from a tuple of `Int`s
        static func t(_ tuple: (down: UInt16, up: UInt8)) -> ScanCodes {
            return ScanCodes(down: tuple.down, up: tuple.up)
        }
    }
    
    // Key Scan Codes mapping from https://www.cs.yale.edu/flint/cs422/doc/art-of-asm/pdf/CH20.PDF
    // Page 1154, Table 72: PC Keyboard Scan Codes (in hex)
    /// Converts macOS key code to IBM scan code for key up and down
    /// The "up" scan codes are currently unused in UTM due to SPICE:
    /// we instead send keyUp with the "down" scan code.
    /// (See also `CSInput.sendKey:type:code`)
    static let keyCodeToScanCodes: [Int:ScanCodes] = [
        kVK_Escape:             .t((down: 0x01, up: 0x81)),
        kVK_ANSI_1:             .t((down: 0x02, up: 0x82)),
        kVK_ANSI_2:             .t((down: 0x03, up: 0x83)),
        kVK_ANSI_3:             .t((down: 0x04, up: 0x84)),
        kVK_ANSI_4:             .t((down: 0x05, up: 0x85)),
        kVK_ANSI_5:             .t((down: 0x06, up: 0x86)),
        kVK_ANSI_6:             .t((down: 0x07, up: 0x87)),
        kVK_ANSI_7:             .t((down: 0x08, up: 0x88)),
        kVK_ANSI_8:             .t((down: 0x09, up: 0x89)),
        kVK_ANSI_9:             .t((down: 0x0a, up: 0x8a)),
        kVK_ANSI_0:             .t((down: 0x0b, up: 0x8b)),
        kVK_ANSI_Minus:         .t((down: 0x0c, up: 0x8c)),
        kVK_ANSI_Equal:         .t((down: 0x0d, up: 0x8d)),
        kVK_Delete:             .t((down: 0x0e, up: 0x8e)), /// IBM name is `backspace`
        kVK_Tab:                .t((down: 0x0f, up: 0x8f)),
        kVK_ANSI_Q:             .t((down: 0x10, up: 0x90)),
        kVK_ANSI_W:             .t((down: 0x11, up: 0x91)),
        kVK_ANSI_E:             .t((down: 0x12, up: 0x92)),
        kVK_ANSI_R:             .t((down: 0x13, up: 0x93)),
        kVK_ANSI_T:             .t((down: 0x14, up: 0x94)),
        kVK_ANSI_Y:             .t((down: 0x15, up: 0x95)),
        kVK_ANSI_U:             .t((down: 0x16, up: 0x96)),
        kVK_ANSI_I:             .t((down: 0x17, up: 0x97)),
        kVK_ANSI_O:             .t((down: 0x18, up: 0x98)),
        kVK_ANSI_P:             .t((down: 0x19, up: 0x99)),
        kVK_ANSI_LeftBracket:   .t((down: 0x1a, up: 0x9a)),
        kVK_ANSI_RightBracket:  .t((down: 0x1b, up: 0x9b)),
        kVK_Return:             .t((down: 0x1c, up: 0x9c)), /// IBM name is `enter`
        kVK_Control:            .t((down: 0x1d, up: 0x9d)),
        kVK_ANSI_A:             .t((down: 0x1e, up: 0x9e)),
        kVK_ANSI_S:             .t((down: 0x1f, up: 0x9f)),
        kVK_ANSI_D:             .t((down: 0x20, up: 0xa0)),
        kVK_ANSI_F:             .t((down: 0x21, up: 0xa1)),
        kVK_ANSI_G:             .t((down: 0x22, up: 0xa2)),
        kVK_ANSI_H:             .t((down: 0x23, up: 0xa3)),
        kVK_ANSI_J:             .t((down: 0x24, up: 0xa4)),
        kVK_ANSI_K:             .t((down: 0x25, up: 0xa5)),
        kVK_ANSI_L:             .t((down: 0x26, up: 0xa6)),
        kVK_ANSI_Semicolon:     .t((down: 0x27, up: 0xa7)),
        kVK_ANSI_Quote:         .t((down: 0x28, up: 0xa8)),
        kVK_ANSI_Grave:         .t((down: 0x29, up: 0xa9)),
        kVK_Shift:              .t((down: 0x2a, up: 0xaa)),
        kVK_ANSI_Backslash:     .t((down: 0x2b, up: 0xab)),
        kVK_ANSI_Z:             .t((down: 0x2c, up: 0xac)),
        kVK_ANSI_X:             .t((down: 0x2d, up: 0xad)),
        kVK_ANSI_C:             .t((down: 0x2e, up: 0xae)),
        kVK_ANSI_V:             .t((down: 0x2f, up: 0xaf)),
        kVK_ANSI_B:             .t((down: 0x30, up: 0xb0)),
        kVK_ANSI_N:             .t((down: 0x31, up: 0xb1)),
        kVK_ANSI_M:             .t((down: 0x32, up: 0xb2)),
        kVK_ANSI_Comma:         .t((down: 0x33, up: 0xb3)),
        kVK_ANSI_Period:        .t((down: 0x34, up: 0xb4)),
        kVK_ANSI_Slash:         .t((down: 0x35, up: 0xb5)),
        kVK_RightShift:         .t((down: 0x36, up: 0xb6)),
        // Print screen not available in Carbon
        kVK_Option:             .t((down: 0x38, up: 0xb8)), /// IBM name is `alt`
        kVK_Space:              .t((down: 0x39, up: 0xb9)),
        kVK_CapsLock:           .t((down: 0x3a, up: 0xba)),
        kVK_F1:                 .t((down: 0x3b, up: 0xbb)),
        kVK_F2:                 .t((down: 0x3c, up: 0xbc)),
        kVK_F3:                 .t((down: 0x3d, up: 0xbd)),
        kVK_F4:                 .t((down: 0x3e, up: 0xbe)),
        kVK_F5:                 .t((down: 0x3f, up: 0xbf)),
        kVK_F6:                 .t((down: 0x40, up: 0xc0)),
        kVK_F7:                 .t((down: 0x41, up: 0xc1)),
        kVK_F8:                 .t((down: 0x42, up: 0xc2)),
        kVK_F9:                 .t((down: 0x43, up: 0xc3)),
        kVK_F10:                .t((down: 0x44, up: 0xc4)),
        // Numlock not available in Carbon
        // Scroll lock not available in Carbon
        // Number pad Home, up, pgUp not available in Carbon
        kVK_ANSI_KeypadMinus:   .t((down: 0x4a, up: 0xca)),
        // Number pad left, center, right not available in Carbon
        kVK_ANSI_KeypadPlus:    .t((down: 0x4e, up: 0xce)),
        // Number pad end, down, pgDown, insert not available in Carbon
        kVK_ANSI_KeypadClear:   .t((down: 0x45, up: 0xC5)), /// in IBM this is num lock, so we send that
        kVK_ANSI_KeypadDivide:  .t((down: 0xe035, up: 0xb5)),
        kVK_ANSI_KeypadEnter:   .t((down: 0xe01c, up: 0x9c)),
        kVK_ANSI_Keypad0:       .t((down: 0x52, up: 0xD2)),
        kVK_ANSI_Keypad1:       .t((down: 0x4F, up: 0xCF)),
        kVK_ANSI_Keypad2:       .t((down: 0x50, up: 0xD0)),
        kVK_ANSI_Keypad3:       .t((down: 0x51, up: 0xD1)),
        kVK_ANSI_Keypad4:       .t((down: 0x4B, up: 0xCB)),
        kVK_ANSI_Keypad5:       .t((down: 0x4C, up: 0xCC)),
        kVK_ANSI_Keypad6:       .t((down: 0x4D, up: 0xCD)),
        kVK_ANSI_Keypad7:       .t((down: 0x47, up: 0xC7)),
        kVK_ANSI_Keypad8:       .t((down: 0x48, up: 0xC8)),
        kVK_ANSI_Keypad9:       .t((down: 0x49, up: 0xC9)),
        kVK_ANSI_KeypadDecimal: .t((down: 0x53, up: 0xD3)),
        kVK_ANSI_KeypadEquals:  .t((down: 0x00, up: 0x00)), /// Not found on IBM
        kVK_ANSI_KeypadMultiply:.t((down: 0x37, up: 0xB7)),
        kVK_F11:                .t((down: 0x57, up: 0xd7)),
        kVK_F12:                .t((down: 0x58, up: 0xd8)),
        // Insert not available in Carbon
        kVK_ForwardDelete:      .t((down: 0xe053, up: 0xd3)), /// IBM name is `delete`
        kVK_Home:               .t((down: 0xe047, up: 0xc7)),
        kVK_End:                .t((down: 0xe04f, up: 0xcf)),
        kVK_PageUp:             .t((down: 0xe049, up: 0xc9)),
        kVK_PageDown:           .t((down: 0xe051, up: 0xd1)),
        kVK_LeftArrow:          .t((down: 0xe04b, up: 0xcb)),
        kVK_RightArrow:         .t((down: 0xe04d, up: 0xcd)),
        kVK_UpArrow:            .t((down: 0xe048, up: 0xc8)),
        kVK_DownArrow:          .t((down: 0xe050, up: 0xd0)),
        kVK_RightOption:        .t((down: 0xe038, up: 0xb8)), /// IBM name is `right alt`
        kVK_RightControl:       .t((down: 0xe01d, up: 0x9d)),
        // Pause not available in Carbon
        /* Additional non-IBM keys */
        kVK_Command:            .t((down: 0xe05b, up: 0xdb)),
        kVK_RightCommand:       .t((down: 0xe05c, up: 0xdc)),
        kVK_ISO_Section:        .t((down: 0x56, up: 0xD6)),
        kVK_VolumeUp:           .t((down: 0xe030, up: 0xb0)),
        kVK_VolumeDown:         .t((down: 0xe02e, up: 0xae)),
        kVK_Mute:               .t((down: 0xE020, up: 0xa0)),
        kVK_F13:                .t((down: 0x64, up: 0xe4)),
        kVK_F14:                .t((down: 0x65, up: 0xe5)),
        kVK_F15:                .t((down: 0x66, up: 0xe6)),
        kVK_F16:                .t((down: 0x67, up: 0xe7)),
        kVK_F17:                .t((down: 0x68, up: 0xe8)),
        kVK_F18:                .t((down: 0x69, up: 0xe9)),
        kVK_F19:                .t((down: 0x6a, up: 0xea)),
        kVK_F20:                .t((down: 0x6b, up: 0xeb)),
        kVK_JIS_Yen:            .t((down: 0x7d, up: 0xfd)),
        kVK_JIS_Underscore:     .t((down: 0x73, up: 0xf3)),
        kVK_JIS_KeypadComma:    .t((down: 0x5c, up: 0xdc)),
        kVK_JIS_Eisu:           .t((down: 0x73, up: 0xf3)),
        kVK_JIS_Kana:           .t((down: 0x70, up: 0xf0)),
        /* The Function and help keys doesn't have a scan code */
        kVK_Function:           .t((down: 0x00, up: 0x00)),
        kVK_Help:               .t((down: 0x00, up: 0x00))
    ]
}

extension KeyCodeMap {
    /// Support ASCII control characters
    /// https://jkorpela.fi/chars/c0.html
    fileprivate static func tryHandleSpecialChar(_ character: Character) -> Dictionary<String, Int>? {
        if let ascii = character.asciiValue {
            var virtKeyCode: Int?
            if ascii <= 31 {
                /// Control held
                switch ascii {
                case 1: virtKeyCode = kVK_ANSI_A
                case 2: virtKeyCode = kVK_ANSI_B
                case 3: virtKeyCode = kVK_ANSI_C
                case 4: virtKeyCode = kVK_ANSI_D
                case 5: virtKeyCode = kVK_ANSI_E
                case 6: virtKeyCode = kVK_ANSI_F
                case 7: virtKeyCode = kVK_ANSI_G
                case 8: virtKeyCode = kVK_ANSI_H
                case 9: virtKeyCode = kVK_ANSI_I
                case 10: virtKeyCode = kVK_ANSI_J
                case 11: virtKeyCode = kVK_ANSI_K
                case 12: virtKeyCode = kVK_ANSI_L
                case 13: virtKeyCode = kVK_ANSI_M
                case 14: virtKeyCode = kVK_ANSI_N
                case 15: virtKeyCode = kVK_ANSI_O
                case 16: virtKeyCode = kVK_ANSI_P
                case 17: virtKeyCode = kVK_ANSI_Q
                case 18: virtKeyCode = kVK_ANSI_R
                case 19: virtKeyCode = kVK_ANSI_S
                case 20: virtKeyCode = kVK_ANSI_T
                case 21: virtKeyCode = kVK_ANSI_U
                case 22: virtKeyCode = kVK_ANSI_V
                case 23: virtKeyCode = kVK_ANSI_W
                case 24: virtKeyCode = kVK_ANSI_Y
                case 25: virtKeyCode = kVK_ANSI_X
                case 26: virtKeyCode = kVK_ANSI_Z
                case 27: virtKeyCode = kVK_ANSI_LeftBracket
                case 28: virtKeyCode = kVK_ANSI_Backslash
                case 29: virtKeyCode = kVK_ANSI_RightBracket
                case 30:
                    if var dict = characterToKeyCode(character: "^") {
                        dict["control"] = 1
                        return dict
                    } else { return nil }
                case 31:
                    if var dict = characterToKeyCode(character: "_") {
                        dict["control"] = 1
                        return dict
                    } else { return nil }
                default:
                    virtKeyCode = nil
                }
                if let virtKeyCode = virtKeyCode {
                    return [
                        "option": 0,
                        "shift": 0,
                        "function": 0,
                        "control": 1,
                        "command": 0,
                        "virtKeyCode": virtKeyCode
                    ]
                }
            } else if ascii == 127 {
                /// Delete key
                return [
                    "option": 0,
                    "shift": 0,
                    "function": 0,
                    "control": 1,
                    "command": 0,
                    "virtKeyCode": kVK_Delete
                ]
            }
        }
        return nil
    }
}
