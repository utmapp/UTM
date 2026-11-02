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

struct SettingsView: View {
    var body: some View {
        SettingsTabsView()
            .frame(width: 810)
            .frame(minHeight: 100, idealHeight: 400, maxHeight: .infinity)
    }
}

private struct SettingsTabsView: NSViewControllerRepresentable {
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

        var title: LocalizedStringKey {
            switch self {
            case .application:
                return "General"
            case .display:
                return "Display"
            case .sound:
                return "Sound"
            case .input:
                return "Input"
            case .network:
                return "Network"
            case .file:
                return "Files"
            case .server:
                return "Server"
            }
        }

        var systemImage: String {
            switch self {
            case .application:
                return "gearshape"
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
                NetworkSettingsView()
            case .file:
                FileSettingsView()
            case .server:
                ServerSettingsView()
            }
        }
    }

    func makeNSViewController(context: Context) -> SettingsTabViewController {
        let panes = Selection.allCases.map { category in
            let content = HStack(alignment: .top) {
                category.view
                    .frame(minHeight: category == .network ? 300 : 0)
                    .padding()
                Spacer()
            }
            .frame(width: 810, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            let host = NSHostingController(rootView: AnyView(content))
            let item = NSTabViewItem(viewController: host)
            item.identifier = String(describing: category)
            item.label = category.title.localizedString
            item.image = NSImage(systemSymbolName: category.systemImage, accessibilityDescription: item.label)
            return item
        }
        return SettingsTabViewController(panes: panes)
    }

    func updateNSViewController(_ controller: SettingsTabViewController, context: Context) {}
}

@MainActor
final class SettingsTabViewController: NSTabViewController {
    private var isCommittingSelection = false
    private var isTransitioning = false
    private var pendingItem: NSTabViewItem?
    private var isReady = false

    init(panes: [NSTabViewItem]) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []
        canPropagateSelectedChildViewControllerTitle = false
        tabViewItems = panes
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !isReady else { return }
        isReady = true
        guard let window = view.window, let item = tabView.selectedTabViewItem else { return }
        window.toolbar?.displayMode = .iconAndLabel
        window.toolbar?.allowsUserCustomization = false
        window.toolbarStyle = .preference
        window.title = item.label
        DispatchQueue.main.async {
            window.setFrame(self.frame(for: item, in: window), display: true)
        }
    }

    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        let allowed = super.tabView(tabView, shouldSelect: tabViewItem)
        guard allowed, isReady, !isCommittingSelection, let item = tabViewItem else { return allowed }
        if isTransitioning {
            pendingItem = item
            return false
        }
        guard item !== tabView.selectedTabViewItem else { return allowed }
        transition(to: item)
        return false
    }

    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
        item?.target = self
        item?.action = #selector(selectPane(_:))
        return item
    }

    @objc private func selectPane(_ sender: NSToolbarItem) {
        guard let item = tabViewItems.first(where: { $0.identifier as? String == sender.itemIdentifier.rawValue }) else { return }
        if isTransitioning {
            pendingItem = item
        } else {
            tabView.selectTabViewItem(item)
        }
    }

    private func frame(for item: NSTabViewItem, in window: NSWindow) -> NSRect {
        guard let content = item.viewController?.view else { return window.frame }
        content.layoutSubtreeIfNeeded()
        let contentHeight = max(100, ceil(content.fittingSize.height))
        let chromeHeight = window.frame.height - window.contentLayoutRect.height
        var frame = window.frame
        let height = contentHeight + chromeHeight
        frame.origin.y += frame.height - height
        frame.size.height = height
        return frame
    }

    private func transition(to item: NSTabViewItem) {
        guard let window = view.window,
              let oldView = tabView.selectedTabViewItem?.viewController?.view,
              let newView = item.viewController?.view,
              let index = tabViewItems.firstIndex(of: item) else { return }
        isTransitioning = true
        Task { @MainActor in
            await animate(duration: 0.12) {
                oldView.animator().alphaValue = 0
            }
            let frame = self.frame(for: item, in: window)
            await animate(duration: 0.22) {
                window.animator().setFrame(frame, display: true)
            }
            newView.alphaValue = 0
            isCommittingSelection = true
            selectedTabViewItemIndex = index
            isCommittingSelection = false
            window.title = item.label
            await animate(duration: 0.12) {
                newView.animator().alphaValue = 1
            }
            oldView.alphaValue = 1
            isTransitioning = false
            if let pending = pendingItem {
                pendingItem = nil
                if pending !== item {
                    transition(to: pending)
                }
            }
        }
    }

    private func animate(duration: TimeInterval, changes: @MainActor () -> Void) async {
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            } completionHandler: {
                continuation.resume()
            }
        }
    }
}

private enum SettingsLayout {
    static let formWidth: CGFloat = 576
}

private struct SettingsPane<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var pickerWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content
        }
        .toggleStyle(.checkbox)
        .environment(\.settingsPickerWidth, pickerWidth)
        .onPreferenceChange(SettingsPickerWidth.self) { pickerWidth = $0 }
        .frame(width: SettingsLayout.formWidth)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

private extension EnvironmentValues {
    var settingsPickerWidth: CGFloat {
        get { self[SettingsPickerWidth.self] }
        set { self[SettingsPickerWidth.self] = newValue }
    }
}

private struct SettingsPickerWidth: EnvironmentKey, PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SettingsPicker<Value: Equatable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [(String, Value)]
    @Environment(\.settingsPickerWidth) private var width

    init(_ title: LocalizedStringKey, selection: Binding<Value>, options: [(String, Value)]) {
        self.title = title
        self._selection = selection
        self.options = options
    }

    var body: some View {
        let sizingButton = NSPopUpButton(frame: .zero, pullsDown: false)
        sizingButton.font = .systemFont(ofSize: NSFont.systemFontSize)
        sizingButton.addItems(withTitles: options.map { NSLocalizedString($0.0, comment: "") })
        sizingButton.sizeToFit()
        let naturalWidth = ceil(sizingButton.frame.width)
        return NativeSettingsPicker(title: title, selection: $selection, options: options)
            .frame(width: max(width, naturalWidth), height: 22, alignment: .leading)
            .preference(key: SettingsPickerWidth.self, value: naturalWidth)
    }
}

struct NativeSettingsPicker<Value: Equatable>: NSViewRepresentable {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [(String, Value)]
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.setContentHuggingPriority(.init(1), for: .horizontal)
        button.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        button.target = context.coordinator
        button.action = #selector(Coordinator.select(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let titles = options.map { NSLocalizedString($0.0, comment: "") }
        if button.itemTitles != titles {
            button.removeAllItems()
            button.addItems(withTitles: titles)
        }
        if let index = options.firstIndex(where: { $0.1 == selection }) {
            button.selectItem(at: index)
        } else {
            button.select(nil)
        }
        button.isEnabled = isEnabled
        button.setAccessibilityLabel(title.localizedString)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: NativeSettingsPicker
        init(_ parent: NativeSettingsPicker) { self.parent = parent }
        @objc func select(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.options.indices.contains(index) else { return }
            parent.selection = parent.options[index].1
        }
    }
}

private struct SettingsRow<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content
    private let alignment: VerticalAlignment

    init(_ title: LocalizedStringKey, alignment: VerticalAlignment = .firstTextBaseline, @ViewBuilder content: () -> Content) {
        self.title = title
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 12) {
            (Text(title) + Text(verbatim: ":"))
                .multilineTextAlignment(.trailing)
                .frame(width: SettingsLayout.formWidth / 4, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ApplicationSettingsView: View {
    @AppStorage("KeepRunningAfterLastWindowClosed") var isKeepRunningAfterLastWindowClosed = false
    @AppStorage("HideDockIcon") var isDockIconHidden = false
    @AppStorage("ShowMenuIcon") var isMenuIconShown = false
    @AppStorage("PreventIdleSleep") var isPreventIdleSleep = false
    @AppStorage("NoQuitConfirmation") var isNoQuitConfirmation = false
    @AppStorage("NoUsbPrompt") var isNoUsbPrompt = false
    @AppStorage("QuitRunningVirtualMachinesPolicy") var quitPolicy = UTMQuitPolicy.saveState.rawValue

    @State private var isConfirmResetAutoConnect = false

    var body: some View {
        SettingsPane {
            SettingsRow("Application") {
                Toggle(isOn: $isKeepRunningAfterLastWindowClosed, label: {
                    Text("Keep running after all windows and virtual machines are closed")
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
            }
            SettingsRow("Sleep") {
                Toggle(isOn: $isPreventIdleSleep, label: {
                    Text("Prevent system from sleeping when any VM is running")
                })
            }
            SettingsRow("Running VMs on quit") {
                SettingsPicker(
                    "Running VMs on quit",
                    selection: $quitPolicy,
                    options: [
                        ("Save State (Default)", UTMQuitPolicy.saveState.rawValue),
                        ("Request Power Down", UTMQuitPolicy.requestPowerDown.rawValue)
                    ]
                )
                .fixedSize(horizontal: true, vertical: false)
                .help("Choose whether UTM saves the state of running virtual machines or requests that their guest operating systems shut down when UTM quits.")
            }
            SettingsRow("Closing a VM") {
                Toggle(isOn: $isNoQuitConfirmation, label: {
                    Text("Do not show confirmation when closing a running VM")
                }).help("Closing a VM without properly shutting it down could result in data loss.")
            }
            SettingsRow("QEMU USB") {
                Toggle(isOn: $isNoUsbPrompt, label: {
                    Text("Do not show prompt when USB device is plugged in")
                })
                Button("Reset auto connect devices…") {
                    isConfirmResetAutoConnect.toggle()
                }.help("Clears all saved USB devices.")
                .padding(.top, 6)
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
    @AppStorage("FullScreenUseCameraHousingArea") var isFullScreenUseCameraHousingArea = false
    @AppStorage("QEMURendererBackend") var qemuRendererBackend: UTMQEMURendererBackend = .qemuRendererBackendDefault
    @AppStorage("QEMUVulkanDriver") var qemuVulkanDriver: UTMQEMUVulkanDriver = .qemuVulkanDriverDefault
    @AppStorage("QEMUDirectXDriver") var qemuDirectXDriver: UTMQEMUDirectXDriver = .qemuDirectXDriverDefault
    @AppStorage("QEMURendererFPSLimit") var qemuRendererFpsLimit: Int = 0

    private var isVulkanSupported: Bool {
        qemuRendererBackend == .qemuRendererBackendDefault || qemuRendererBackend == .qemuRendererBackendAngleMetal
    }

    private static var hasD3DMetal: Bool = {
        let d3dMetalFramework = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/D3DMetal.framework")
        return FileManager.default.fileExists(atPath: d3dMetalFramework.path)
    }()

    private var isD3DMetalAvailable: Bool {
        if qemuDirectXDriver == .qemuDirectXDriverD3DMetal {
            return true // always show option if already selected
        } else {
            if #available(macOS 14, *) {
                return Self.hasD3DMetal && UTMQemuVirtualMachine.canRunD3DMetal
            } else {
                return false
            }
        }
    }

    private var vulkanDriverOptions: [(String, UTMQEMUVulkanDriver)] {
        var options: [(String, UTMQEMUVulkanDriver)] = [
            ("Default", .qemuVulkanDriverDefault),
            ("Disabled", .qemuVulkanDriverDisabled),
            ("MoltenVK", .qemuVulkanDriverMoltenVK)
        ]
        if #available(macOS 26, *) {
            options.append(("KosmicKrisp", .qemuVulkanDriverKosmicKrisp))
        }
        return options
    }

    var body: some View {
        SettingsPane {
            SettingsRow("Screenshots") {
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
            SettingsRow("Full Screen") {
                Toggle(isOn: $isFullScreenUseCameraHousingArea) {
                    Text("Fill the area beside the camera housing in full screen")
                }.help("If enabled, a full screen VM display will use the entire screen including the area beside the built-in camera. The menu bar will cover this area while it is revealed.")
            }
            SettingsRow("Renderer Backend") {
                SettingsPicker(
                    "Renderer Backend",
                    selection: $qemuRendererBackend,
                    options: [
                        ("Default", .qemuRendererBackendDefault),
                        ("ANGLE (OpenGL)", .qemuRendererBackendAngleGL),
                        ("ANGLE (Metal)", .qemuRendererBackendAngleMetal),
                        ("Apple Core OpenGL", .qemuRendererBackendCGL)
                    ]
                ).help("By default, the best renderer for this device will be used. You can override this with to always use a specific renderer. This only applies to QEMU VMs with GPU accelerated graphics.")
            }
            SettingsRow("Vulkan Driver") {
                SettingsPicker(
                    "Vulkan Driver",
                    selection: $qemuVulkanDriver,
                    options: vulkanDriverOptions
                ).help("Select the Vulkan driver to use for host passthrough rendering. Vulkan requires guest drivers to be installed.")
                .disabled(!isVulkanSupported)
                .onChange(of: qemuRendererBackend) { _ in
                    if !isVulkanSupported {
                        qemuVulkanDriver = .qemuVulkanDriverDefault
                    }
                }
            }
            SettingsRow("DirectX Driver") {
                SettingsPicker(
                    "DirectX Driver",
                    selection: $qemuDirectXDriver,
                    options: [("Default", .qemuDirectXDriverDefault), ("Disabled", .qemuDirectXDriverDisabled), ("DXMT", .qemuDirectXDriverDXMT)] + (isD3DMetalAvailable ? [("D3DMetal", .qemuDirectXDriverD3DMetal)] : [])
                ).help("Select the DirectX driver to use for host passthrough rendering. DirectX requires guest drivers to be installed.")
                .disabled(!isVulkanSupported)
                .onChange(of: qemuRendererBackend) { _ in
                    if !isVulkanSupported {
                        qemuDirectXDriver = .qemuDirectXDriverDefault
                    }
                }
                if !isVulkanSupported {
                    Text("The selected renderer backend does not support Vulkan.")
                }
            }
            SettingsRow("FPS Limit") {
                HStack(spacing: 8) {
                    NumberTextField("", number: $qemuRendererFpsLimit, prompt: "None")
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .help("If set, a frame limit can improve smoothness in rendering by preventing stutters when set to the lowest value your device can handle.")
                    Stepper("FPS Limit", value: $qemuRendererFpsLimit, in: 0...240, step: 15).labelsHidden()
                }.fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

struct SoundSettingsView: View {
    @AppStorage("QEMUSoundBackend") var qemuSoundBackend: UTMQEMUSoundBackend = .qemuSoundBackendDefault
    
    var body: some View {
        SettingsPane {
            SettingsRow("QEMU Sound") {
                SettingsPicker(
                    "Sound Backend",
                    selection: $qemuSoundBackend,
                    options: [
                        ("Default", .qemuSoundBackendDefault),
                        ("SPICE with GStreamer (Input & Output)", .qemuSoundBackendSPICE),
                        ("CoreAudio (Output Only)", .qemuSoundBackendCoreAudio)
                    ]
                ).help("By default, the best backend for the target will be used. If the selected backend is not available for any reason, an alternative will automatically be selected.")
            }
        }
    }
}

struct InputSettingsView: View {
    private enum ModifierKeyMapping: Hashable {
        case none
        case ctrlCmd
        case cmdOpt
    }

    @AppStorage("FullScreenAutoCapture") var isFullScreenAutoCapture = false
    @AppStorage("WindowFocusAutoCapture") var isWindowFocusAutoCapture = false
    @AppStorage("OptionAsMetaKey") var isOptionAsMetaKey = false
    @AppStorage("CtrlRightClick") var isCtrlRightClick = false
    @AppStorage("AlternativeCaptureKey") var isAlternativeCaptureKey = false
    @AppStorage("IsCapsLockKey") var isCapsLockKey = false
    @AppStorage("IsNumLockForced") var isNumLockForced = false
    @AppStorage("IsCtrlCmdSwapped") var isCtrlCmdSwapped = false
    @AppStorage("IsCmdOptSwapped") var isCmdOptSwapped = false
    @AppStorage("InvertScroll") var isInvertScroll = false
    @AppStorage("HandleInitialClick") var isHandleInitialClick = false
    @AppStorage("IsISOKeySwapped") var isISOKeySwapped = false

    @State private var isKeyboardShortcutsShown = false

    private var modifierKeyMappingBinding: Binding<ModifierKeyMapping> {
        Binding(get: {
            if isCtrlCmdSwapped {
                return .ctrlCmd
            } else if isCmdOptSwapped {
                return .cmdOpt
            } else {
                return .none
            }
        }, set: { mapping in
            isCtrlCmdSwapped = mapping == .ctrlCmd
            isCmdOptSwapped = mapping == .cmdOpt
        })
    }
    
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
                Picker("Control, Option, and Command keys", selection: modifierKeyMappingBinding) {
                    Text("Default").tag(ModifierKeyMapping.none)
                    Text("Swap Control (⌃) and Command (⌘)").tag(ModifierKeyMapping.ctrlCmd)
                    Text("Swap Command (⌘) and Option (⌥)").tag(ModifierKeyMapping.cmdOpt)
                }.help("This does not apply to key binding outside the guest.")
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
    @objc dynamic var QuitRunningVirtualMachinesPolicy: Int { UTMQuitPolicy.saveState.rawValue }
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
