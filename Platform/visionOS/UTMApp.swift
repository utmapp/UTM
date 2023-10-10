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

import SwiftUI

@MainActor
struct UTMApp: App {
    @State private var data: UTMData = UTMData()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private let vmSessionCreatedNotification = NotificationCenter.default.publisher(for: .vmSessionCreated)
    private let vmSessionEndedNotification = NotificationCenter.default.publisher(for: .vmSessionEnded)

    var body: some Scene {
        WindowGroup(id: "home") {
            ContentView()
            .environmentObject(data)
            .onReceive(vmSessionCreatedNotification) { output in
                let newSession = output.userInfo!["Session"] as! VMSessionState
                openWindow(value: newSession.newWindow())
            }
            .onReceive(vmSessionEndedNotification) { output in
                let endedSession = output.userInfo!["Session"] as! VMSessionState
                for globalWindow in endedSession.windows {
                    dismissWindow(value: globalWindow)
                }
            }
        }.commands {
            VMCommands()
        }
        .windowResizability(.contentMinSize)
        WindowGroup(for: VMSessionState.GlobalWindowID.self) { $globalID in
            if let globalID = globalID, let session = VMSessionState.allActiveSessions[globalID.sessionID] {
                VMWindowView(id: globalID.windowID).environmentObject(session)
                    .onAppear {
                        // currently we only support one session, so close the home window
                        dismissWindow(id: "home")
                    }
            }
        }
        .windowResizability(.contentMinSize)
    }
}
