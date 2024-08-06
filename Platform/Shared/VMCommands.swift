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

struct VMCommands: Commands {
    @Environment(\.openURL) private var openURL
    
    @CommandsBuilder
    var body: some Commands {
        #if !WITH_REMOTE // FIXME: implement remote feature
        CommandGroup(replacing: .newItem) {
            Button(action: { NotificationCenter.default.post(name: NSNotification.NewVirtualMachine, object: nil) }, label: {
                Text("New…")
            }).keyboardShortcut(KeyEquivalent("n"))
            Button(action: { NotificationCenter.default.post(name: NSNotification.OpenVirtualMachine, object: nil) }, label: {
                Text("Open…")
            }).keyboardShortcut(KeyEquivalent("o"))
        }
        #endif
        SidebarCommands()
        ToolbarCommands()
        CommandGroup(replacing: .help) {
            Button(action: { NotificationCenter.default.post(name: NSNotification.ShowReleaseNotes, object: nil) }, label: {
                Text("What's New")
            }).keyboardShortcut(KeyEquivalent("1"), modifiers: [.command, .control])
            Button(action: { openLink("https://mac.getutm.app/gallery/") }, label: {
                Text("Virtual Machine Gallery")
            }).keyboardShortcut(KeyEquivalent("2"), modifiers: [.command, .control])
            Button(action: { openLink("https://docs.getutm.app/") }, label: {
                Text("Support")
            }).keyboardShortcut(KeyEquivalent("3"), modifiers: [.command, .control])
            Button(action: { openLink("https://mac.getutm.app/licenses/") }, label: {
                Text("License")
            }).keyboardShortcut(KeyEquivalent("4"), modifiers: [.command, .control])
        }
    }
    
    private func openLink(_ url: String) {
        openURL(URL(string: url)!)
    }
}

extension NSNotification {
    static let NewVirtualMachine = NSNotification.Name("NewVirtualMachine")
    static let OpenVirtualMachine = NSNotification.Name("OpenVirtualMachine")
    static let ShowReleaseNotes = NSNotification.Name("ShowReleaseNotes")
}
