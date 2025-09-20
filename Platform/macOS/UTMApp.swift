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

import SwiftUI
import AppIntents

struct UTMApp: App {
    let data: UTMData
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate

    init() {
        let data = UTMData()
        self.data = data
        if #available(macOS 13, *) {
            AppDependencyManager.shared.add(dependency: data)
        }
    }

    @ViewBuilder
    var homeWindow: some View {
        ContentView().environmentObject(data)
            .onAppear {
                appDelegate.data = data
                NSApp.scriptingDelegate = appDelegate
            }
            .onReceive(.vmSessionError) { notification in
                if let message = notification.userInfo?["Message"] as? String {
                    data.showErrorAlert(message: message)
                }
            }  
    }
    
    @SceneBuilder
    var oldBody: some Scene {
        WindowGroup {
            homeWindow
        }.commands {
            VMCommands()
        }
        Settings {
            SettingsView()
        }
    }
    
    @available(macOS 13, *)
    @SceneBuilder
    var newBody: some Scene {
        Window("UTM Library", id: "home") {
            homeWindow
                .navigationTitle("UTM")
        }.commands {
            VMCommands()
        }
        Settings {
            SettingsView()
        }
        UTMMenuBarExtraScene(data: data)
        Window("UTM Server", id: "server") {
            UTMServerView().environmentObject(data.remoteServer.state)
        }
    }
    
    // HACK: SwiftUI doesn't provide if-statement support in SceneBuilder
    var body: some Scene {
        if #available(macOS 13, *) {
            return newBody
        } else {
            return oldBody
        }
    }
    
}
