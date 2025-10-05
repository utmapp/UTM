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

@resultBuilder
struct QEMUArgumentBuilder {
    static func buildBlock(_ components: [QEMUArgumentFragment]...) -> [QEMUArgumentFragment] {
        let merged = components.flatMap { $0 }
        var combined: [QEMUArgumentFragment] = []
        var current = QEMUArgumentFragment()
        for fragment in merged {
            current.merge(fragment)
            if current.isFinal {
                combined.append(current)
                current = QEMUArgumentFragment()
            }
        }
        if !current.string.isEmpty {
            combined.append(current)
        }
        return combined
    }
    
    static func buildExpression(_ fragment: QEMUArgumentFragment) -> [QEMUArgumentFragment] {
        [fragment]
    }
    
    static func buildExpression(_ fragments: [QEMUArgumentFragment]) -> [QEMUArgumentFragment] {
        fragments
    }
    
    static func buildExpression(_ arguments: [QEMUArgument]) -> [QEMUArgumentFragment] {
        arguments.map { QEMUArgumentFragment(from: $0) }
    }
    
    static func buildExpression(_ string: String) -> [QEMUArgumentFragment] {
        [.init(string)]
    }
    
    static func buildExpression(_ constant: any QEMUConstant) -> [QEMUArgumentFragment] {
        [.init(constant.rawValue)]
    }
    
    static func buildExpression(_ assignment: ()) -> [QEMUArgumentFragment] {
        []
    }
    
    static func buildExpression(_ url: URL) -> [QEMUArgumentFragment] {
        var arg = QEMUArgumentFragment(url.path.replacingOccurrences(of: ",", with: ",,"))
        arg.fileUrls = [url]
        arg.seperator = ""
        return [arg]
    }
    
    static func buildExpression<I: FixedWidthInteger>(_ int: I) -> [QEMUArgumentFragment] {
        [.init("\(int)")]
    }
    
    static func buildEither(first component: [QEMUArgumentFragment]) -> [QEMUArgumentFragment] {
        component
    }
    
    static func buildEither(second component: [QEMUArgumentFragment]) -> [QEMUArgumentFragment] {
        component
    }
    
    static func buildArray(_ components: [[QEMUArgumentFragment]]) -> [QEMUArgumentFragment] {
        components.flatMap { $0 }
    }
    
    static func buildOptional(_ component: [QEMUArgumentFragment]?) -> [QEMUArgumentFragment] {
        component ?? []
    }
    
    static func buildFinalResult(_ component: [QEMUArgumentFragment]) -> [QEMUArgument] {
        component.map { QEMUArgument(from: $0) }
    }
}
