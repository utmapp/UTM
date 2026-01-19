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

struct QEMUArgument: Hashable, Identifiable, Codable {
    /// Argument string passed to QEMU
    var string: String
    
    /// Optional URL resource that must be accessed
    var fileUrls: [URL]?
    
    let id = UUID()
    
    init(_ string: String) {
        self.string = string
    }
    
    init(from fragment: QEMUArgumentFragment) {
        string = fragment.string
        fileUrls = fragment.fileUrls
    }
    
    init(from decoder: Decoder) throws {
        string = try String(from: decoder)
    }
    
    func encode(to encoder: Encoder) throws {
        try string.encode(to: encoder)
    }
    
    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

struct QEMUArgumentFragment: Hashable {
    /// String representing this fragment
    var string: String
    
    /// Optional URL resource(s) that must be accessed
    var fileUrls: [URL]?
    
    /// If false, this fragment will be merged with the preceding one
    private(set) var isFinal: Bool

    /// If true, we already escaped the commas
    private var isUrlFragment: Bool = false

    /// Separate the previous fragment if non-empty
    private var seperator: String = ","

    init(_ fragment: String = "") {
        string = fragment
        isFinal = false
    }

    init(urlFragment: URL) {
        string = urlFragment.path
        isFinal = false
        isUrlFragment = true
        fileUrls = [urlFragment]
        seperator = ""
    }

    init(final fragment: String) {
        string = fragment
        isFinal = true
    }
    
    init(from argument: QEMUArgument) {
        string = argument.string
        fileUrls = argument.fileUrls
        isFinal = true
    }
    
    func hash(into hasher: inout Hasher) {
        string.hash(into: &hasher)
        fileUrls?.hash(into: &hasher)
        isFinal.hash(into: &hasher)
    }
    
    mutating func merge(_ other: QEMUArgumentFragment) {
        if self.string.count == 0 {
            self.isUrlFragment = other.isUrlFragment
        }
        if self.string.count > 0 && other.string.count > 0 {
            var otherString = other.string
            if other.isUrlFragment {
                otherString = otherString.replacingOccurrences(of: ",", with: ",,")
            }
            self.string += other.seperator + otherString
        } else {
            self.string += other.string
        }
        self.isFinal = self.isFinal || other.isFinal
        if let fileUrls = other.fileUrls {
            if self.fileUrls == nil {
                self.fileUrls = fileUrls
            } else {
                self.fileUrls!.append(contentsOf: fileUrls)
            }
        }
    }
}
