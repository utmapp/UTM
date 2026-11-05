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

#if DEBUG
import Foundation

/// Launch arguments the UI tests pass to start the app in a known state.
///
/// Only a test build honours them: its bundle identifier carries the test prefix, so the
/// container it resets is its own. Every other bundle identifier ignores them.
enum UTMTestSupport {
    /// The bundle identifier prefix of a test build (`PRODUCT_BUNDLE_PREFIX=com.utmapp.test`).
    static let testBundlePrefix = "com.utmapp.test."

    /// Suppresses what a user would otherwise be shown on launch: the release notes sheet,
    /// the server, and VM screenshots.
    static let testModeArgument = "-UTMTestMode"
    
    /// Empties the app's defaults and its documents before anything reads them.
    static let resetArgument = "-UTMTestReset"
    
    /// Whether this launch of a test build asked for test mode.
    static var isTestMode: Bool {
        CommandLine.arguments.contains(testModeArgument) && Bundle.main.bundleIdentifier?.hasPrefix(testBundlePrefix) == true
    }
    
    static func applyLaunchArguments() {
        let arguments = CommandLine.arguments
        guard arguments.contains(testModeArgument) || arguments.contains(resetArgument) else {
            return
        }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier, bundleIdentifier.hasPrefix(testBundlePrefix) else {
            logger.debug("Test launch arguments are ignored outside a test build.")
            return
        }
        let defaults = UserDefaults.standard
        if arguments.contains(resetArgument) {
            // only ever empty a container of our own, never a real Documents folder
            let documents = UTMData.defaultStorageUrl
            let path = documents.path
            guard path.contains("/Library/Containers/") || path.contains("/CoreSimulator/") else {
                logger.debug("Not resetting \(path): it is not an app container.")
                return
            }
            defaults.removePersistentDomain(forName: bundleIdentifier)
            let fileManager = FileManager.default
            if let items = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) {
                for item in items {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
        if arguments.contains(testModeArgument) {
            // registered for this launch only, so nothing persists past the test
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            defaults.register(defaults: [
                "ReleaseNotesLastVersion": version,
                "ServerAutostart": false,
                "NoScreenshot": true,
            ])
        }
    }
}
#endif
