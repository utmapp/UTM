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

@available(macOS 11, *)
struct SettingsView: View {
    private enum Selection: CaseIterable, Identifiable {
        case application
        case display
        case sound
        case input
        case network
        case file
        case server

        var id: Self {
            return self
        }

        var isAvailable: Bool {
            if self == .network {
                if #unavailable(macOS 12) {
                    return false
                }
            }
            return true
        }

        var title: LocalizedStringKey {
            switch self {
            case .application:
                return "Application"
            case .display:
                return "Display"
            case .sound:
                return "Sound"
            case .input:
                return "Input"
            case .network:
                return "Network"
            case .file:
                return "File"
            case .server:
                return "Server"
            }
        }

        var systemImage: String {
            switch self {
            case .application:
                return "app.badge"
            case .display:
                return "rectangle.on.rectangle"
            case .sound:
                return "speaker.wave.2"
            case .input:
                return "keyboard"
            case .network:
                return "network"
            case .file:
                return "folder"
            case .server:
                return "server.rack"
            }
        }

        @ViewBuilder
        var view: some View {
            switch self {
            case .application:
                ApplicationSettingsView()
            case .display:
                DisplaySettingsView()
            case .sound:
                SoundSettingsView()
            case .input:
                InputSettingsView()
            case .network:
                if #available(macOS 12, *) {
                    NetworkSettingsView()
                } else {
                    EmptyView()
                }
            case .file:
                FileSettingsView()
            case .server:
                ServerSettingsView()
            }
        }
    }

    @State private var selection: Selection = .application

    var body: some View {
        if #available(macOS 26, *) {
            newBody
        } else {
            oldBody
        }
    }

    @available(macOS 15, *)
    @ViewBuilder
    var newBody: some View {
        NavigationSplitView {
            List(Selection.allCases, selection: $selection) { category in
                if category.isAvailable {
                    Label(category.title, systemImage: category.systemImage)
                }
            }.toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    selection.view.padding()
                    Spacer()
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    var oldBody: some View {
        TabView {
            ForEach(Selection.allCases) { category in
                if category.isAvailable {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            category.view.padding()
                            Spacer()
                        }
                        Spacer()
                    }
                    .tabItem {
                        Label(category.title, systemImage: category.systemImage)
                    }
                }
            }
        }
    }
}

struct ApplicationSettingsView: View {
    @AppStorage("KeepRunningAfterLastWindowClosed") var isKeepRunningAfterLastWindowClosed = false
    @AppStorage("HideDockIcon") var isDockIconHidden = false
    @AppStorage("ShowMenuIcon") var isMenuIconShown = false
    @AppStorage("PreventIdleSleep") var isPreventIdleSleep = false
    @AppStorage("NoQuitConfirmation") var isNoQuitConfirmation = false
    @AppStorage("NoUsbPrompt") var isNoUsbPrompt = false

    @State private var isConfirmResetAutoConnect = false

    var body: some View {
        Form {
            Toggle(isOn: $isKeepRunningAfterLastWindowClosed, label: {
                Text("Keep UTM running after last window is closed and all VMs are shut down")
            })
            if #available(macOS 13, *) {
                Toggle(isOn: $isDockIconHidden.inverted, label: {
                    Text("Show dock icon")
                }).onChange(of: isDockIconHidden) { newValue in
                    if newValue {
                        isMenuIconShown = true
                        isKeepRunningAfterLastWindowClosed = true
                    }
                }
                Toggle(isOn: $isMenuIconShown, label: {
                    Text("Show menu bar icon")
                }).disabled(isDockIconHidden)
            }
            Toggle(isOn: $isPreventIdleSleep, label: {
                Text("Prevent system from sleeping when any VM is running")
            })
            Toggle(isOn: $isNoQuitConfirmation, label: {
                Text("Do not show confirmation when closing a running VM")
            }).help("Closing a VM without properly shutting it down could result in data loss.")

            Section(header: Text("QEMU USB")) {
                Toggle(isOn: $isNoUsbPrompt, label: {
                    Text("Do not show prompt when USB device is plugged in")
                })
                Button("Reset auto connect devices…") {
                    isConfirmResetAutoConnect.toggle()
                }.help("Clears all saved USB devices.")
                .alert(isPresented: $isConfirmResetAutoConnect) {
                    Alert(title: Text("Do you wish to reset all saved USB devices?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Reset")) {
                        UTMUSBManager.shared.usbDevices.removeAll()
                    })
                }
            }
        }
    }
}

struct DisplaySettingsView: View {
    @AppStorage("NoScreenshot") var isNoScreenshot = false
    @AppStorage("NoSaveScreenshot") var isNoSaveScreenshot = false
    @AppStorage("QEMURendererBackend") var qemuRendererBackend: UTMQEMURendererBackend = .qemuRendererBackendDefault
    @AppStorage("QEMUVulkanDriver") var qemuVulkanDriver: UTMQEMUVulkanDriver = .qemuVulkanDriverDefault
    @AppStorage("QEMURendererFPSLimit") var qemuRendererFpsLimit: Int = 0

    private var isVulkanSupported: Bool {
        qemuRendererBackend == .qemuRendererBackendDefault || qemuRendererBackend == .qemuRendererBackendAngleMetal
    }

    var body: some View {
        Form {
            Section(header: Text("Display")) {
                Toggle(isOn: $isNoScreenshot) {
                    Text("Disable VM screenshot")
                }.help("No VM screenshots will be taken.")
                .onChange(of: isNoScreenshot) { newValue in
                    isNoSaveScreenshot = newValue
                }
                Toggle(isOn: $isNoSaveScreenshot) {
                    Text("Do not save VM screenshot to disk")
                }.help("If enabled, any existing screenshot will be deleted the next time the VM is started.")
                .disabled(isNoScreenshot)
            }
            
            Section(header: Text("QEMU Graphics Acceleration")) {
                Picker("Renderer Backend", selection: $qemuRendererBackend) {
                    Text("Default").tag(UTMQEMURendererBackend.qemuRendererBackendDefault)
                    Text("ANGLE (OpenGL)").tag(UTMQEMURendererBackend.qemuRendererBackendAngleGL)
                    Text("ANGLE (Metal)").tag(UTMQEMURendererBackend.qemuRendererBackendAngleMetal)
                    Text("Apple Core OpenGL").tag(UTMQEMURendererBackend.qemuRendererBackendCGL)
                }.help("By default, the best renderer for this device will be used. You can override this with to always use a specific renderer. This only applies to QEMU VMs with GPU accelerated graphics.")
                Picker("Vulkan Driver", selection: $qemuVulkanDriver) {
                    Text("Default").tag(UTMQEMUVulkanDriver.qemuVulkanDriverDefault)
                    Text("Disabled").tag(UTMQEMUVulkanDriver.qemuVulkanDriverDisabled)
                    Text("MoltenVK").tag(UTMQEMUVulkanDriver.qemuVulkanDriverMoltenVK)
                    if #available(macOS 15, *) {
                        Text("KosmicKrisp").tag(UTMQEMUVulkanDriver.qemuVulkanDriverKosmicKrisp)
                    }
                }.help("Select the Vulkan driver to use for host passthrough rendering. Vulkan requires guest drivers to be installed.")
                .disabled(!isVulkanSupported)
                .onChange(of: qemuRendererBackend) { _ in
                    if !isVulkanSupported {
                        qemuVulkanDriver = .qemuVulkanDriverDefault
                    }
                }
                if !isVulkanSupported {
                    Text("The selected renderer backend does not support Vulkan.")
                }
                HStack {
                    Stepper("FPS Limit", value: $qemuRendererFpsLimit, in: 0...240, step: 15)
                    NumberTextField("", number: $qemuRendererFpsLimit, prompt: "None")
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .help("If set, a frame limit can improve smoothness in rendering by preventing stutters when set to the lowest value your device can handle.")
                }
            }
        }
    }
}

struct SoundSettingsView: View {
    @AppStorage("QEMUSoundBackend") var qemuSoundBackend: UTMQEMUSoundBackend = .qemuSoundBackendDefault
    
    var body: some View {
        Form {
            Section(header: Text("QEMU Sound")) {
                Picker("Sound Backend", selection: $qemuSoundBackend) {
                    Text("Default").tag(UTMQEMUSoundBackend.qemuSoundBackendDefault)
                    Text("SPICE with GStreamer (Input & Output)").tag(UTMQEMUSoundBackend.qemuSoundBackendSPICE)
                    Text("CoreAudio (Output Only)").tag(UTMQEMUSoundBackend.qemuSoundBackendCoreAudio)
                }.help("By default, the best backend for the target will be used. If the selected backend is not available for any reason, an alternative will automatically be selected.")
            }
        }
    }
}

struct InputSettingsView: View {
    @AppStorage("FullScreenAutoCapture") var isFullScreenAutoCapture = false
    @AppStorage("WindowFocusAutoCapture") var isWindowFocusAutoCapture = false
    @AppStorage("OptionAsMetaKey") var isOptionAsMetaKey = false
    @AppStorage("CtrlRightClick") var isCtrlRightClick = false
    @AppStorage("AlternativeCaptureKey") var isAlternativeCaptureKey = false
    @AppStorage("IsCapsLockKey") var isCapsLockKey = false
    @AppStorage("IsNumLockForced") var isNumLockForced = false
    @AppStorage("IsCtrlCmdSwapped") var isCtrlCmdSwapped = false
    @AppStorage("InvertScroll") var isInvertScroll = false
    @AppStorage("HandleInitialClick") var isHandleInitialClick = false
    @AppStorage("IsISOKeySwapped") var isISOKeySwapped = false

    @State private var isKeyboardShortcutsShown = false
    
    var body: some View {
        Form {
            Section(header: Text("Mouse/Keyboard")) {
                Toggle(isOn: $isFullScreenAutoCapture) {
                    Text("Capture input automatically when entering full screen")
                }.help("If enabled, input capture will toggle automatically when entering and exiting full screen mode.")
                Toggle(isOn: $isWindowFocusAutoCapture) {
                    Text("Capture input automatically when window is focused")
                }.help("If enabled, input capture will toggle automatically when the VM's window is focused.")
            }
            
            Section(header: Text("Console")) {
                Toggle(isOn: $isOptionAsMetaKey, label: {
                    Text("Option (⌥) is Meta key")
                }).help("If enabled, Option will be mapped to the Meta key which can be useful for emacs. Otherwise, option will work as the system intended (such as for entering international text).")
            }
            
            Section(header: Text("QEMU Pointer")) {
                Toggle(isOn: $isCtrlRightClick, label: {
                    Text("Hold Control (⌃) for right click")
                })
                Toggle(isOn: $isInvertScroll, label: {
                    Text("Invert scrolling")
                }).help("If enabled, scroll wheel input will be inverted.")
                Toggle(isOn: $isHandleInitialClick) {
                    Text("Handle input on initial click")
                }.help("If enabled, when the VM is out of focus, the first click will be handled by the VM. Otherwise, the first click will only bring the window into focus.")
            }
            
            Section(header: Text("QEMU Keyboard")) {
                Button("Keyboard Shortcuts…") {
                    isKeyboardShortcutsShown.toggle()
                }.help("Set up custom keyboard shortcuts that can be triggered from the keyboard menu.")
                Toggle(isOn: $isAlternativeCaptureKey, label: {
                    Text("Use Command+Option (⌘+⌥) for input capture/release")
                }).help("If disabled, the default combination Control+Option (⌃+⌥) will be used.")
                Toggle(isOn: $isCapsLockKey, label: {
                    Text("Caps Lock (⇪) is treated as a key")
                }).help("If enabled, caps lock will be handled like other keys. If disabled, it is treated as a toggle that is synchronized with the host.")
                Toggle(isOn: $isNumLockForced, label: {
                    Text("Num Lock is forced on")
                }).help("If enabled, num lock will always be on to the guest. Note this may make your keyboard's num lock indicator out of sync.")
                Toggle(isOn: $isCtrlCmdSwapped, label: {
                    Text("Swap Control (⌃) and Command (⌘) keys")
                }).help("This does not apply to key binding outside the guest.")
                Toggle(isOn: $isISOKeySwapped) {
                    Text("Swap the leftmost key on the number row and the key next to left shift on ISO keyboards")
                }.help("This only applies to ISO layout keyboards.")
            }
            .sheet(isPresented: $isKeyboardShortcutsShown) {
                VMKeyboardShortcutsView().padding()
                    .frame(idealWidth: 400)
            }
        }
    }
}

@available(macOS 12, *)
struct NetworkSettingsView: View {
    @AppStorage("IsRegenerateMACOnClone") var isRegenerateMACOnClone = false
    @AppStorage("HostNetworks") var hostNetworksData: Data = Data()
    @State private var hostNetworks: [UTMConfigurationHostNetwork] = []
    @State private var selectedID: UUID?
    @State private var isImporterPresented: Bool = false
    
    private func loadData() {
        hostNetworks = (try? PropertyListDecoder().decode([UTMConfigurationHostNetwork].self, from: hostNetworksData)) ?? []
    }
    
    private func saveData() {
        hostNetworksData = (try? PropertyListEncoder().encode(hostNetworks)) ?? Data()
    }
    
    var body: some View {
        Form {
            Section(header: Text("Cloning")) {
                Toggle("Regenerate MAC addresses on clone", isOn: $isRegenerateMACOnClone)
                    .help("When cloning a VM, regenerate MAC addresses on every network interface to prevent conflicts.")
            }
            Section(header: Text("Host Networks")) {
                Table($hostNetworks, selection: $selectedID) {
                    TableColumn("Name") { $network in
                        TextField(
                            "Name",
                            text: $network.name
                        )
                        .labelsHidden()
                    }
                    TableColumn("UUID") { $network in
                        TextField(
                            "UUID",
                            text: $network.uuid,
                            onEditingChanged: { (editingChanged) in
                                if !editingChanged && UUID(uuidString: network.uuid) != nil {
                                    saveData()
                                }
                            }
                        )
                        .labelsHidden()
                        .autocorrectionDisabled()
                        .foregroundStyle(UUID(uuidString: network.uuid) == nil ? .red : .primary)
                    }
                    .width(min: 160)
                }.help("QEMU machines in 'Host' network mode can be placed in the same network to communicate with each other.")
                HStack {
                    Button("Import from VMware Fusion") {
                        isImporterPresented.toggle()
                    }.fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.data]) { result in
                        
                        if let url = try? result.get() {
                            for network in UTMConfigurationHostNetwork.parseVMware(from: url) {
                                if !hostNetworks.contains(where: {$0.uuid == network.uuid}) {
                                    hostNetworks.append(network)
                                }
                            }
                            
                            saveData()
                        }
                    }.help("Navigate to '/Library/Preferences/VMware Fusion' (⌘+Shift+G) and select the 'networking' file")
                    Spacer()
                    Button("Delete") {
                        hostNetworks.removeAll { network in
                            network.id == selectedID
                        }
                        selectedID = nil
                        saveData()
                        
                    }.disabled(selectedID == nil)
                    Button("Add") {
                        let network = UTMConfigurationHostNetwork(name: "Network \(hostNetworks.count)")
                        hostNetworks.append(network)
                        saveData()
                    }
                }
            }
        }.onAppear(perform: loadData)
    }
}

struct FileSettingsView: View {
    @AppStorage("UseFileLock") var isUseFileLock = true

    var body: some View {
        Form {
            Section(header: Text("QEMU Backend")) {
                Toggle(isOn: $isUseFileLock) {
                    Text("Lock drive images when in use")
                }.help("If enabled, all writable drive images will be locked when the VM is running. Read-only drive images will not be locked.")
            }
        }
    }
}

struct ServerSettingsView: View {
    private let defaultPort = 21589

    @AppStorage("ServerAutostart") var isServerAutostart: Bool = false
    @AppStorage("ServerExternal") var isServerExternal: Bool = false
    @AppStorage("ServerAutoblock") var isServerAutoblock: Bool = false
    @AppStorage("ServerPort") var serverPort: Int = 0
    @AppStorage("ServerPasswordRequired") var isServerPasswordRequired: Bool = false
    @AppStorage("ServerPassword") var serverPassword: String = ""

    // note it is okay to store the server password in plaintext in the settings plist because if the attacker is able to see the password,
    // they can gain execution in UTM application context... which is the context needed to read the password.

    var body: some View {
        Form {
            Section(header: Text("Startup")) {
                Toggle("Automatically start UTM server", isOn: $isServerAutostart)
            }
            Section(header: Text("Network")) {
                Toggle("Reject unknown connections by default", isOn: $isServerAutoblock)
                    .help("If checked, you will not be prompted about any unknown connection and they will be rejected.")
                Toggle("Allow access from external clients", isOn: $isServerExternal)
                    .help("By default, the server is only available on LAN but setting this will use UPnP/NAT-PMP to port forward to WAN.")
                    .onChange(of: isServerExternal) { newValue in
                        if newValue {
                            if serverPort == 0 {
                                serverPort = defaultPort
                            }
                            if !isServerPasswordRequired {
                                isServerPasswordRequired = true
                            }
                        }
                    }
                NumberTextField("", number: $serverPort, prompt: "Any")
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .help("Specify a port number to listen on. This is required if external clients are permitted.")
                    .onChange(of: serverPort) { newValue in
                        if newValue == 0 {
                            isServerExternal = false
                        }
                        if newValue < 0 || newValue >= UInt16.max {
                            serverPort = defaultPort
                        }
                    }
            }
            Section(header: Text("Authentication")) {
                Toggle("Require Password", isOn: $isServerPasswordRequired)
                    .disabled(isServerExternal)
                    .help("If enabled, clients must enter a password. This is required if you want to access the server externally.")
                    .onChange(of: isServerPasswordRequired) { newValue in
                        if newValue && serverPassword.count == 0 {
                            serverPassword = .random(length: 32)
                        }
                    }
                TextField("Password", text: $serverPassword)
                    .disabled(!isServerPasswordRequired)
            }
        }
    }
}

extension UserDefaults {
    @objc dynamic var KeepRunningAfterLastWindowClosed: Bool { false }
    @objc dynamic var ShowMenuIcon: Bool { false }
    @objc dynamic var HideDockIcon: Bool { false }
    @objc dynamic var PreventIdleSleep: Bool { false }
    @objc dynamic var NoQuitConfirmation: Bool { false }
    @objc dynamic var NoCursorCaptureAlert: Bool { false }
    @objc dynamic var FullScreenAutoCapture: Bool { false }
    @objc dynamic var OptionAsMetaKey: Bool { false }
    @objc dynamic var CtrlRightClick: Bool { false }
    @objc dynamic var NoUsbPrompt: Bool { false }
    @objc dynamic var AlternativeCaptureKey: Bool { false }
    @objc dynamic var IsCapsLockKey: Bool { false }
    @objc dynamic var IsNumLockForced: Bool { false }
    @objc dynamic var NoSaveScreenshot: Bool { false }
    @objc dynamic var InvertScroll: Bool { false }
    @objc dynamic var QEMURendererBackend: Int { 0 }
    @objc dynamic var QEMURendererFPSLimit: Int { 0 }
}

@available(macOS 11, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
