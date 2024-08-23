//
// Copyright © 2020 osy. All rights reserved.
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

import Logging
import TipKit

let logger = Logger(label: "com.utmapp.UTM") { label in
    var utmLogger = UTMLoggingSwift(label: label)
    var stdOutLogger = StreamLogHandler.standardOutput(label: label)
    #if DEBUG
    utmLogger.logLevel = .debug
    stdOutLogger.logLevel = .debug
    #endif
    return MultiplexLogHandler([
        utmLogger,
        stdOutLogger
    ])
}

@main
class Main {
    static var jitAvailable = true
    
    static func main() {
        #if (os(iOS) || os(visionOS)) && WITH_JIT
        // check if we have jailbreak
        if jb_spawn_ptrace_child(CommandLine.argc, CommandLine.unsafeArgv) {
            logger.info("JIT: ptrace() child spawn trick")
        } else if jb_has_jit_entitlement() {
            logger.info("JIT: found entitlement")
        } else if jb_has_cs_disabled() {
            logger.info("JIT: CS_KILL disabled")
        } else if jb_has_cs_execseg_allow_unsigned() {
            logger.info("JIT: CS_EXECSEG_ALLOW_UNSIGNED set")
        } else if jb_enable_ptrace_hack() {
            logger.info("JIT: ptrace() hack supported")
        } else {
            logger.info("JIT: ptrace() hack failed")
            jitAvailable = false
        }
        // raise memlimits on jailbroken devices
        if jb_increase_memlimit() {
            logger.info("MEM: successfully removed memory limits")
        }
        #endif
        // do patches
        UTMPatches.patchAll()
        #if os(iOS) || os(visionOS)
        // register defaults
        registerDefaultsFromSettingsBundle()
        // register tips
        if #available(iOS 17, macOS 14, *) {
            try? Tips.configure()
        }
        #endif
        UTMApp.main()
    }
    
    // https://stackoverflow.com/a/44675628
    static private func registerDefaultsFromSettingsBundle() {
        let userDefaults = UserDefaults.standard

        if let settingsURL = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
            let settings = NSDictionary(contentsOf: settingsURL),
            let preferences = settings["PreferenceSpecifiers"] as? [NSDictionary] {

            var defaultsToRegister = [String: AnyObject]()
            for prefSpecification in preferences {
                if let key = prefSpecification["Key"] as? String,
                    let value = prefSpecification["DefaultValue"] {

                    defaultsToRegister[key] = value as AnyObject
                    logger.debug("registerDefaultsFromSettingsBundle: (\(key), \(value)) \(type(of: value))")
                }
            }
            
            // register version numbers
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
                userDefaults.set(version, forKey: "LastBootedVersion")
            }
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] {
                userDefaults.set(build, forKey: "LastBootedBuild")
            }

            userDefaults.register(defaults: defaultsToRegister)
        } else {
            logger.debug("registerDefaultsFromSettingsBundle: Could not find Settings.bundle")
        }
    }
}
