//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

import SwiftUI

/// Read-only view of the complete command line UTM runs.
struct VMConfigQEMUCommandLineView: View {
    @ObservedObject var config: UTMQemuConfiguration
    
    /// One option per line, in the form of a shell command with line continuations.
    private var commandLine: String {
        var lines = ["qemu-system-\(config.system.architecture.rawValue)"]
        for argument in config.allArguments {
            let string = argument.string.contains(" ") ? "\"\(argument.string)\"" : argument.string
            if string.hasPrefix("-") {
                lines.append(string)
            } else {
                lines[lines.count - 1] += " \(string)"
            }
        }
        return lines.joined(separator: " \\\n    ")
    }
    
    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading) {
            Text("Command Line")
                .font(.headline)
            List {
                Text(commandLine)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }.listStyle(.bordered)
        }
        #else
        Section(header: Text("Command Line")) {
            Text(commandLine)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
        #endif
    }
}

struct VMConfigQEMUCommandLineView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigQEMUCommandLineView(config: config)
            .padding()
    }
}
