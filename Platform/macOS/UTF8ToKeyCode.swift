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

/// Based on https://stackoverflow.com/a/64344453/4236245
/// Translated to Swift by conath
class UTF8ToKeyCode {
    private static var keyMapDict: Dictionary<String, Dictionary<String, UInt16>>!
    private static var modFlagDict: Dictionary<String, UInt>!
    private static var modFlags: [UInt]!
    
    static func createKeyMapIfNeeded() {
        if keyMapDict == nil {
            keyMapDict = makeKeyMap()
        }
    }
    
    static func characterToKeyCode(character: Character) -> Dictionary<String, UInt16> {
        createKeyMapIfNeeded()

        /*
         The returned dictionary contains entries for the virtual key code and boolean flags
         for modifier keys used for the character.
         */
        return keyMapDict[String(character)]!
    }

    private static func makeKeyMap() -> Dictionary<String, Dictionary<String, UInt16>> {
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
        var keyMapDict = Dictionary<String, Dictionary<String, UInt16>>()

        // run through 128 base key codes to see what they produce
        for keyCode: UInt16 in 0..<128 {
            // create dummy NSEvent from a CGEvent for a keypress
            let coreEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
            let keyEvent = NSEvent(cgEvent: coreEvent)!

            if (keyEvent.type == .keyDown) {
                // this repeat/while loop through every permutation of modifier keys for a given key code
                repeat {
                    var subDict = Dictionary<String, UInt16>()
                    // cerate dictionary containing current modifier keys and virtual key code
                    for key: String in modFlagDict.keys {
                        let modKeyIsUsed = ((modFlagDict[key]! & modifiers) != 0)
                        subDict[key] = NSNumber(booleanLiteral: modKeyIsUsed).uint16Value
                    }
                    subDict["virtKeyCode"] = keyCode

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
}
