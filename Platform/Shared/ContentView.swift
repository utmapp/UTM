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
#if !os(macOS)
import IQKeyboardManagerSwift
#endif

#if WITH_QEMU_TCI
let productName = "UTM SE"
#else
let productName = "UTM"
#endif

struct ContentView: View {
    @State private var editMode = false
    @EnvironmentObject private var data: UTMData
    @State private var newPopupPresented = false
    @State private var openSheetPresented = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VMNavigationListView()
        .overlay(data.showSettingsModal ? AnyView(EmptyView()) : AnyView(BusyOverlay()))
        #if os(macOS)
        .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
        #endif
        .disabled(data.busy && !data.showNewVMSheet && !data.showSettingsModal)
        .onOpenURL(perform: handleURL)
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .onReceive(NSNotification.NewVirtualMachine) { _ in
            data.newVM()
        }.onReceive(NSNotification.OpenVirtualMachine) { _ in
            data.showNewVMSheet = false
            openSheetPresented = false
            // FIXME: SwiftUI bug on iOS requires this wait
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                openSheetPresented = true
            }
        }.fileImporter(isPresented: $openSheetPresented, allowedContentTypes: [.UTM, .UTMextension], allowsMultipleSelection: true, onCompletion: selectImportedUTM)
        .onAppear {
            Task {
                await data.listRefresh()
            }
            #if os(macOS)
            NSWindow.allowsAutomaticWindowTabbing = false
            #else
            data.triggeriOSNetworkAccessPrompt()
            IQKeyboardManager.shared.enable = true
            #if !WITH_QEMU_TCI
            if !Main.jitAvailable {
                data.busyWorkAsync {
                    let jitStreamerAttach = UserDefaults.standard.bool(forKey: "JitStreamerAttach")
                    if #available(iOS 15, *), jitStreamerAttach {
                        try await data.jitStreamerAttach()
                        return
                    }

                    #if canImport(AltKit)
                    if await data.isAltServerCompatible {
                        try await data.startAltJIT()
                        return
                    }
                    #endif

                    // ignore error when we are running on a HV only build
                    if !jb_has_hypervisor() {
                        throw NSLocalizedString("Your version of iOS does not support running VMs while unmodified. You must either run UTM while jailbroken or with a remote debugger attached. See https://getutm.app/install/ for more details.", comment: "ContentView")
                    }
                }
            }
            #endif
            #endif
        }
    }
    
    private func handleURL(url: URL) {
        data.busyWorkAsync {
            if url.isFileURL {
                try await importUTM(url: url)
            } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let scheme = components.scheme,
                      scheme.lowercased() == "utm" {
                try await handleUTMURL(with: components)
            }
        }
    }
    
    private func importUTM(url: URL) async throws {
        guard url.isFileURL else {
            return // ignore
        }
        try await data.importUTM(from: url)
    }
    
    private func selectImportedUTM(result: Result<[URL], Error>) {
        data.busyWorkAsync {
            let urls = try result.get()
            for url in urls {
                try await data.importUTM(from: url)
            }
        }
    }
    
    @MainActor private func handleUTMURL(with components: URLComponents) async throws {
        func findVM() async -> UTMVirtualMachine? {
            if let vmName = components.queryItems?.first(where: { $0.name == "name" })?.value {
                return await data.virtualMachines.first(where: { $0.detailsTitleLabel == vmName })
            } else {
                return nil
            }
        }
        
        if let action = components.host {
            switch action {
            case "start":
                if let vm = await findVM(), vm.state == .vmStopped {
                    data.run(vm: vm)
                }
                break
            case "stop":
                if let vm = await findVM(), vm.state == .vmStarted {
                    vm.requestVmStop(force: true)
                    try? data.stop(vm: vm)
                }
                break
            case "restart":
                if let vm = await findVM(), vm.state == .vmStarted {
                    vm.requestVmReset()
                }
                break
            case "pause":
                if let vm = await findVM(), vm.state == .vmStarted {
                    let shouldSaveOnPause: Bool
                    if let vm = vm as? UTMQemuVirtualMachine {
                        shouldSaveOnPause = !vm.isRunningAsSnapshot
                    } else {
                        shouldSaveOnPause = true
                    }
                    vm.requestVmPause(save: shouldSaveOnPause)
                }
            case "resume":
                if let vm = await findVM(), vm.state == .vmPaused {
                    vm.requestVmResume()
                }
                break
            case "sendText":
                if let vm = await findVM(), vm.state == .vmStarted {
                    data.automationSendText(to: vm, urlComponents: components)
                }
                break
            case "click":
                if let vm = await findVM(), vm.state == .vmStarted {
                    data.automationSendMouse(to: vm, urlComponents: components)
                }
                break
            case "downloadVM":
                data.downloadUTMZip(from: components)
                break
            default:
                return
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
