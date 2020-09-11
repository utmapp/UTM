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

let logger = Logger(label: "com.osy86.UTM")

@main
class Main {
    static var jitAvailable = true
    
    static func main() {
        setupLogging()
        // check if we have jailbreak
        if jb_has_jit_entitlement() {
            logger.info("JIT: found entitlement")
        } else if jb_enable_ptrace_hack() {
            logger.info("JIT: ptrace() hack supported")
        } else {
            logger.info("JIT: ptrace() hack failed")
            jitAvailable = false
        }
        if #available(iOS 14, macOS 11, *) {
            UTMApp.main()
        } else {
            #if os(macOS)
            logger.critical("This version of macOS is not supported!")
            #else
            UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
            #endif
        }
    }
    
    static private func setupLogging() {
        LoggingSystem.bootstrap { label in
            return MultiplexLogHandler([
                UTMLoggingSwift(label: label),
                StreamLogHandler.standardOutput(label: label)
            ])
        }
    }
}
