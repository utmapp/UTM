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
import UniformTypeIdentifiers
#if os(iOS)
import IQKeyboardManagerSwift
#endif
import TipKit

// on visionOS, there is no text to show more than UTM
#if WITH_QEMU_TCI && !os(visionOS)
let productName = "UTM SE"
#elseif WITH_REMOTE && !os(visionOS)
let productName = "UTM Remote"
#else
let productName = "UTM"
#endif

struct ContentView: View {
    @State private var editMode = false
    @EnvironmentObject private var data: UTMData
    @StateObject private var releaseHelper = UTMReleaseHelper()
    @State private var openSheetPresented = false
    @Environment(\.openURL) var openURL
    @AppStorage("ServerAutostart") private var isServerAutostart: Bool = false

    var body: some View {
        VMNavigationListView()
        .overlay(data.showSettingsModal ? AnyView(EmptyView()) : AnyView(BusyOverlay()))
        #if os(macOS) || os(visionOS)
        .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
        #endif
        .disabled(data.busy && !data.showNewVMSheet && !data.showSettingsModal)
        .sheet(isPresented: $releaseHelper.isReleaseNotesShown, onDismiss: {
            releaseHelper.closeReleaseNotes()
            if #available(iOS 17, macOS 14, *) {
                UTMTipCreateVM.isVMListEmpty = data.virtualMachines.count == 0
            }
        }, content: {
            VMReleaseNotesView(helper: releaseHelper).padding()
        })
        .onReceive(NSNotification.ShowReleaseNotes) { _ in
            Task {
                await releaseHelper.fetchReleaseNotes(force: true)
            }
        }
        .onOpenURL(perform: handleURL)
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .onReceive(NSNotification.NewVirtualMachine) { _ in
            data.newVM()
        }.onReceive(NSNotification.OpenVirtualMachine) { _ in
            // VMNavigationListView also gets this notification and closes the wizard sheet
            openSheetPresented = false
            // FIXME: SwiftUI bug on iOS requires this wait
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                openSheetPresented = true
            }
        }.fileImporter(isPresented: $openSheetPresented, allowedContentTypes: [.UTM, .UTMextension], allowsMultipleSelection: true, onCompletion: selectImportedUTM)
        .onDrop(of: [.fileURL], delegate: self)
        .onAppear {
            Task {
                await data.listRefresh()
                await releaseHelper.fetchReleaseNotes()
                if #available(iOS 17, macOS 14, *) {
                    if !releaseHelper.isReleaseNotesShown {
                        UTMTipCreateVM.isVMListEmpty = data.virtualMachines.count == 0
                        UTMTipDonate.timesLaunched += 1
                    }
                }
                #if os(macOS)
                if isServerAutostart {
                    await data.remoteServer.start()
                }
                #endif
            }
            #if os(macOS)
            NSWindow.allowsAutomaticWindowTabbing = false
            #else
            data.triggeriOSNetworkAccessPrompt()
            #if !os(visionOS)
            IQKeyboardManager.shared.enable = true
            #endif
            #if WITH_JIT
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
                    if !UTMCapabilities.current.contains(.hasHypervisorSupport) {
                        throw NSLocalizedString("Your version of iOS does not support running VMs while unmodified. You must either run UTM while jailbroken or with a remote debugger attached. See https://getutm.app/install/ for more details.", comment: "ContentView")
                    }
                }
            }
            #endif
            #endif
        }
        #if WITH_SERVER
        .onChange(of: isServerAutostart) { newValue in
            if newValue {
                Task {
                    if isServerAutostart && !data.remoteServer.state.isServerActive {
                        await data.remoteServer.start()
                    }
                }
            }
        }
        #endif
    }
    
    private func handleURL(url: URL) {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.scheme?.lowercased() == "utm",
           components.host == "downloadVM",
           let urlParameter = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let url = URL(string: urlParameter) {
            if data.alertItem == nil {
                data.showNewVMSheet = false
                data.alertItem = .downloadUrl(url)
            }
        } else if url.isFileURL {
            data.busyWorkAsync {
                try await importUTM(url: url)
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
}

extension ContentView: DropDelegate {
    func validateDrop(info: DropInfo) -> Bool {
        !urlsFrom(info: info).isEmpty
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let urls = urlsFrom(info: info)
        data.busyWorkAsync {
            for url in urls {
                
                try await data.importUTM(from: url)
            }
        }
        return true
    }
    
    private func urlsFrom(info: DropInfo) -> [URL] {
        let providers = info.itemProviders(for: [.fileURL])

        var validURLs: [URL] = []

        let group = DispatchGroup()

        providers.forEach { provider in
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if url?.pathExtension == "utm" {
                    validURLs.append(url!)
                }
                group.leave()
            }
        }
        
        group.wait()

        return validURLs
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
