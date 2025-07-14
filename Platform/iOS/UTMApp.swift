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

import SwiftUI
import AppIntents

struct UTMApp: App {
    #if WITH_REMOTE
    private let data: UTMRemoteData
    #else
    private let data: UTMData
    #endif

    init() {
        #if WITH_REMOTE
        let data = UTMRemoteData()
        #else
        let data = UTMData()
        #endif
        self.data = data
        if #available(iOS 16, *) {
            AppDependencyManager.shared.add(dependency: data)
        }
    }

    var body: some Scene {
        WindowGroup {
            UTMSingleWindowView(data: data)
        }.commands {
            VMCommands()
        }
    }
}
