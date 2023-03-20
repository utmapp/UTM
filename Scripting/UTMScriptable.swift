//
// Copyright © 2023 osy. All rights reserved.
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

protocol UTMScriptable: Equatable {}

extension UTMScriptable {
    /// Run a script command asynchronously
    /// - Parameters:
    ///   - command: Script command to run
    ///   - body: What to do
    @MainActor
    func withScriptCommand<Result>(_ command: NSScriptCommand, body: @MainActor @escaping () async throws -> Result) {
        command.suspendExecution()
        // we need to run this in next event loop due to the need to return before calling resume
        DispatchQueue.main.async {
            Task {
                do {
                    let result = try await body()
                    await MainActor.run {
                        if result is Void {
                            command.resumeExecution(withResult: nil)
                        } else {
                            command.resumeExecution(withResult: result)
                        }
                    }
                } catch {
                    await MainActor.run {
                        command.scriptErrorNumber = errOSAGeneralError
                        command.scriptErrorString = error.localizedDescription
                        command.resumeExecution(withResult: nil)
                    }
                }
            }
        }
    }
    
    /// Convert text to data either as a UTF-8 string or as binary encoded in base64
    /// - Parameters:
    ///   - text: Text input
    ///   - isBase64Encoded: If true, the data will be decoded from base64
    /// - Returns: Data or nil on error (or if text was nil)
    func dataFromText(_ text: String?, isBase64Encoded: Bool = false) -> Data? {
        if let text = text {
            if isBase64Encoded {
                return Data(base64Encoded: text)
            } else {
                return text.data(using: .utf8)
            }
        } else {
            return nil
        }
    }
    
    /// Convert data to either UTF-8 string or as binary encoded in base64
    /// - Parameters:
    ///   - data: Data input
    ///   - isBase64Encoded: If true, the text will be encoded to base64
    /// - Returns: Text or nil on error (or if data was nil)
    func textFromData(_ data: Data?, isBase64Encoded: Bool = false) -> String? {
        if let data = data {
            if isBase64Encoded {
                return data.base64EncodedString()
            } else {
                return String(data: data, encoding: .utf8)
            }
        } else {
            return nil
        }
    }
}
