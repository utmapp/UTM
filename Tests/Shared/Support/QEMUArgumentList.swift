//
// Copyright © 2026 osy. All rights reserved.
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

import XCTest
@testable import UTM

/// Lookups over a generated QEMU command line, so tests assert on the
/// arguments they care about instead of on whole command lines.
struct QEMUArgumentList {
    let strings: [String]

    init(_ arguments: [QEMUArgument]) {
        strings = arguments.map(\.string)
    }

    /// The values that follow every occurrence of `flag`, e.g. every `-device`.
    func values(of flag: String) -> [String] {
        strings.indices.compactMap { index in
            strings[index] == flag && index + 1 < strings.count ? strings[index + 1] : nil
        }
    }

    /// The first value following `flag` whose comma-separated options contain `option`.
    func value(of flag: String, containing option: String) -> String? {
        values(of: flag).first { Self.options($0).contains(option) }
    }

    /// The `-device` arguments whose first option (the device type) is `type`.
    func devices(ofType type: String) -> [String] {
        values(of: "-device").filter { Self.options($0).first == type }
    }

    /// Splits a `key=value,key=value` argument into its options, honouring QEMU's
    /// `,,` escape for a comma inside a value.
    static func options(_ argument: String) -> [String] {
        var options: [String] = []
        var current = ""
        var index = argument.startIndex
        while index < argument.endIndex {
            let character = argument[index]
            let next = argument.index(after: index)
            if character == "," && next < argument.endIndex && argument[next] == "," {
                current.append(",")
                index = argument.index(after: next)
            } else if character == "," {
                options.append(current)
                current = ""
                index = next
            } else {
                current.append(character)
                index = next
            }
        }
        options.append(current)
        return options
    }
}
