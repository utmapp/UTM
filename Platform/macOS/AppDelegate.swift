//
// Copyright © 2021 osy. All rights reserved.
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

class AppDelegate: NSObject, NSApplicationDelegate {
    var data: UTMData?
    
    @Setting("KeepRunningAfterLastWindowClosed") private var isKeepRunningAfterLastWindowClosed: Bool = false
    
    private var hasRunningVirtualMachines: Bool {
        guard let vmList = data?.vmWindows.keys else {
            return false
        }
        return vmList.contains(where: { $0.state == .vmStarted || ($0.state == .vmPaused && !$0.hasSaveState) })
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !isKeepRunningAfterLastWindowClosed && !hasRunningVirtualMachines
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let data = data else {
            return .terminateNow
        }

        let vmList = data.vmWindows.keys
        if hasRunningVirtualMachines { // There is at least 1 running VM
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = NSLocalizedString("Confirmation", comment: "VMDisplayWindowController")
                alert.informativeText = NSLocalizedString("Quitting UTM will kill all running VMs.", comment: "VMQemuDisplayMetalWindowController")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "VMDisplayWindowController"))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayWindowController"))
                let confirm = { (response: NSApplication.ModalResponse) in
                    switch response {
                    case .alertFirstButtonReturn:
                        NSApplication.shared.reply(toApplicationShouldTerminate: true)
                    default:
                        NSApplication.shared.reply(toApplicationShouldTerminate: false)
                    }
                }
                if let window = sender.keyWindow {
                    alert.beginSheetModal(for: window, completionHandler: confirm)
                } else {
                    let response = alert.runModal()
                    confirm(response)
                }
            }
            return .terminateLater
        } else if vmList.allSatisfy({ $0.state == .vmStopped || $0.state == .vmPaused }) { // All VMs are stopped or suspended
            return .terminateNow
        } else { // There could be some VMs in other states (starting, pausing, etc.)
            return .terminateCancel
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        /// Clean up caches
        let fileManager = FileManager.default
        guard let cacheUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        guard let urls = try? fileManager.contentsOfDirectory(at: cacheUrl, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        for url in urls {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
