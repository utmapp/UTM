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

import Combine
import SwiftUI

/// Model wrapping a single UTMVirtualMachine for use in views
@MainActor class VMData: ObservableObject {
    /// Underlying virtual machine
    fileprivate(set) var wrapped: (any UTMVirtualMachine)? {
        willSet {
            objectWillChange.send()
        }
        
        didSet {
            subscribeToChildren()
        }
    }
    
    /// Virtual machine configuration
    var config: (any UTMConfiguration)? {
        wrapped?.config
    }
    
    /// Current path of the VM
    var pathUrl: URL {
        if let wrapped = wrapped {
            return wrapped.pathUrl
        } else if let registryEntry = registryEntry {
            return registryEntry.package.url
        } else {
            fatalError()
        }
    }
    
    /// Virtual machine state
    var registryEntry: UTMRegistryEntry? {
        wrapped?.registryEntry ??
        registryEntryWrapped
    }
    
    /// Registry entry before loading
    fileprivate var registryEntryWrapped: UTMRegistryEntry?

    /// Set when we use a temporary UUID because we loaded a legacy entry
    private var uuidUnknown: Bool = false
    
    /// Display VM as "deleted" for UI elements
    ///
    /// This is a workaround for SwiftUI bugs not hiding deleted elements.
    @Published var isDeleted: Bool = false
    
    /// Copy from wrapped VM
    @Published var state: UTMVirtualMachineState = .stopped
    
    /// Copy from wrapped VM
    @Published var screenshot: UTMVirtualMachineScreenshot?

    /// If true, it is possible to hijack the session.
    @Published var isTakeoverAllowed: Bool = false

    /// Allows changes in the config, registry, and VM to be reflected
    private var observers: [AnyCancellable] = []
    
    /// True if the .utm is loaded outside of the default storage
    var isShortcut: Bool {
        isShortcut(pathUrl)
    }

    /// No default init
    fileprivate init() {

    }
    
    /// Create a VM from an existing object
    /// - Parameter vm: VM to wrap
    convenience init(wrapping vm: any UTMVirtualMachine) {
        self.init()
        self.wrapped = vm
        subscribeToChildren()
    }
    
    /// Attempt to a new wrapped UTM VM from a file path
    /// - Parameter url: File path
    convenience init(url: URL) throws {
        self.init()
        try load(from: url)
    }
    
    /// Create a new wrapped UTM VM from a registry entry
    /// - Parameter registryEntry: Registry entry
    convenience init(from registryEntry: UTMRegistryEntry) {
        self.init()
        self.registryEntryWrapped = registryEntry
        subscribeToChildren()
    }
    
    /// Create a new wrapped UTM VM from a dictionary (legacy support)
    /// - Parameter info: Dictionary info
    convenience init?(from info: [String: Any]) {
        guard let bookmark = info["Bookmark"] as? Data,
              let name = info["Name"] as? String,
              let pathString = info["Path"] as? String else {
            return nil
        }
        let legacyEntry = UTMRegistry.shared.entry(uuid: UUID(), name: name, path: pathString, bookmark: bookmark)
        self.init(from: legacyEntry)
        uuidUnknown = true
    }
    
    /// Create a new wrapped UTM VM from only the bookmark data (legacy support)
    /// - Parameter bookmark: Bookmark data
    convenience init(bookmark: Data) {
        self.init()
        let uuid = UUID()
        let name = NSLocalizedString("(Unavailable)", comment: "VMData")
        let pathString = "/\(UUID().uuidString)"
        let legacyEntry = UTMRegistry.shared.entry(uuid: uuid, name: name, path: pathString, bookmark: bookmark)
        self.init(from: legacyEntry)
        uuidUnknown = true
    }
    
    /// Create a new VM from a configuration
    /// - Parameter config: Configuration to create new VM
    convenience init<Config: UTMConfiguration>(creatingFromConfig config: Config, destinationUrl: URL) throws {
        self.init()
        #if !WITH_REMOTE
        if let qemuConfig = config as? UTMQemuConfiguration {
            wrapped = try UTMQemuVirtualMachine(newForConfiguration: qemuConfig, destinationUrl: destinationUrl)
        }
        #endif
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            wrapped = try UTMAppleVirtualMachine(newForConfiguration: appleConfig, destinationUrl: destinationUrl)
        }
        #endif
        subscribeToChildren()
    }
    
    /// Loads the VM
    ///
    /// If the VM is already loaded, it will return true without doing anything.
    /// - Parameter url: URL to load from
    /// - Returns: If load was successful
    func load() throws {
        try load(from: pathUrl)
    }
    
    /// Loads the VM from a path
    ///
    /// If the VM is already loaded, it will return true without doing anything.
    /// - Parameter url: URL to load from
    /// - Returns: If load was successful
    private func load(from url: URL) throws {
        guard !isLoaded else {
            return
        }
        var loaded: (any UTMVirtualMachine)?
        let config = try UTMQemuConfiguration.load(from: url)
        #if !WITH_REMOTE
        if let qemuConfig = config as? UTMQemuConfiguration {
            loaded = try UTMQemuVirtualMachine(packageUrl: url, configuration: qemuConfig, isShortcut: isShortcut(url))
        }
        #endif
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            loaded = try UTMAppleVirtualMachine(packageUrl: url, configuration: appleConfig, isShortcut: isShortcut(url))
        }
        #endif
        guard let vm = loaded else {
            throw VMDataError.virtualMachineNotLoaded
        }
        if let oldEntry = registryEntry, oldEntry.uuid != vm.registryEntry.uuid {
            if uuidUnknown {
                // legacy VMs don't have UUID stored so we made a fake UUID
                UTMRegistry.shared.remove(entry: oldEntry)
            } else {
                // persistent uuid does not match indicating a cloned or legacy VM with a duplicate UUID
                vm.changeUuid(to: oldEntry.uuid, name: nil, copyingEntry: oldEntry)
            }
        }
        wrapped = vm
        uuidUnknown = false
        vm.updateConfigFromRegistry()
        subscribeToChildren()
    }
    
    /// Saves the VM to file
    func save() async throws {
        guard let wrapped = wrapped else {
            throw VMDataError.virtualMachineNotLoaded
        }
        try await wrapped.save()
    }
    
    /// Listen to changes in the underlying object and propogate upwards
    fileprivate func subscribeToChildren() {
        var s: [AnyCancellable] = []
        if let wrapped = wrapped {
            wrapped.onConfigurationChange = { [weak self] in
                self?.objectWillChange.send()
                Task { @MainActor in
                    self?.subscribeToChildren()
                }
            }
            
            wrapped.onStateChange = { [weak self, weak wrapped] in
                Task { @MainActor in
                    if let wrapped = wrapped {
                        self?.state = wrapped.state
                        self?.screenshot = wrapped.screenshot
                    }
                }
            }
        }
        if let qemuConfig = wrapped?.config as? UTMQemuConfiguration {
            s.append(qemuConfig.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            })
        }
        #if os(macOS)
        if let appleConfig = wrapped?.config as? UTMAppleConfiguration {
            s.append(appleConfig.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            })
        }
        #endif
        if let registryEntry = registryEntry {
            s.append(registryEntry.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
                Task { @MainActor in
                    self?.wrapped?.updateConfigFromRegistry()
                }
            })
        }
        observers = s
    }
}

// MARK: - Errors
enum VMDataError: Error {
    case virtualMachineNotLoaded
}

extension VMDataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .virtualMachineNotLoaded:
            return NSLocalizedString("Virtual machine not loaded.", comment: "VMData")
        }
    }
}

// MARK: - Identity
extension VMData: Identifiable {
    public var id: UUID {
        registryEntry?.uuid ??
        config?.information.uuid ??
        UUID()
    }
}

extension VMData: Equatable {
    static func == (lhs: VMData, rhs: VMData) -> Bool {
        if lhs.isLoaded && rhs.isLoaded {
            return lhs.wrapped === rhs.wrapped
        }
        if let lhsEntry = lhs.registryEntryWrapped, let rhsEntry = rhs.registryEntryWrapped {
            return lhsEntry == rhsEntry
        }
        return false
    }
}

extension VMData: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(pathUrl)
        hasher.combine(registryEntryWrapped)
        hasher.combine(isDeleted)
    }
}

// MARK: - VM State
extension VMData {
    func isShortcut(_ url: URL) -> Bool {
        let defaultStorageUrl = UTMData.defaultStorageUrl.standardizedFileURL
        let parentUrl = url.deletingLastPathComponent().standardizedFileURL
        return parentUrl != defaultStorageUrl
    }
    
    /// VM is loaded
    var isLoaded: Bool {
        wrapped != nil
    }
    
    /// VM is stopped
    var isStopped: Bool {
        state == .stopped || state == .paused
    }
    
    /// VM can be modified
    var isModifyAllowed: Bool {
        state == .stopped
    }
    
    /// Display VM as "busy" for UI elements
    var isBusy: Bool {
        state == .pausing ||
        state == .resuming ||
        state == .starting ||
        state == .stopping ||
        state == .saving ||
        state == .resuming
    }
    
    /// VM has been suspended before
    var hasSuspendState: Bool {
        registryEntry?.isSuspended ?? false
    }
}

// MARK: - Home UI elements
extension VMData {
    /// Unavailable string
    private var unavailable: String {
        NSLocalizedString("Unavailable", comment: "VMData")
    }
    
    /// Display title for UI elements
    var detailsTitleLabel: String {
        config?.information.name ??
        registryEntry?.name ??
        unavailable
    }
    
    /// Display subtitle for UI elements
    var detailsSubtitleLabel: String {
        detailsSystemTargetLabel
    }
    
    /// Display icon path for UI elements
    var detailsIconUrl: URL? {
        config?.information.iconURL ?? nil
    }
    
    /// Display user-specified notes for UI elements
    var detailsNotes: String? {
        config?.information.notes ?? nil
    }
    
    /// Display VM target system for UI elements
    var detailsSystemTargetLabel: String {
        if let qemuConfig = config as? UTMQemuConfiguration {
            return qemuConfig.system.target.prettyValue
        }
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            return appleConfig.system.boot.operatingSystem.rawValue
        }
        #endif
        return unavailable
    }
    
    /// Display VM architecture for UI elements
    var detailsSystemArchitectureLabel: String {
        if let qemuConfig = config as? UTMQemuConfiguration {
            return qemuConfig.system.architecture.prettyValue
        }
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            return appleConfig.system.architecture
        }
        #endif
        return unavailable
    }
    
    /// Display RAM (formatted) for UI elements
    var detailsSystemMemoryLabel: String {
        let bytesInMib = Int64(1048576)
        if let qemuConfig = config as? UTMQemuConfiguration {
            return ByteCountFormatter.string(fromByteCount: Int64(qemuConfig.system.memorySize) * bytesInMib, countStyle: .binary)
        }
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            return ByteCountFormatter.string(fromByteCount: Int64(appleConfig.system.memorySize) * bytesInMib, countStyle: .binary)
        }
        #endif
        return unavailable
    }
    
    /// Display current VM state as a string for UI elements
    var stateLabel: String {
        switch state {
        case .stopped:
            if registryEntry?.isSuspended == true {
                return NSLocalizedString("Suspended", comment: "VMData");
            } else {
                return NSLocalizedString("Stopped", comment: "VMData");
            }
        case .starting:
            return NSLocalizedString("Starting", comment: "VMData")
        case .started:
            return NSLocalizedString("Started", comment: "VMData")
        case .pausing:
            return NSLocalizedString("Pausing", comment: "VMData")
        case .paused:
            return NSLocalizedString("Paused", comment: "VMData")
        case .resuming:
            return NSLocalizedString("Resuming", comment: "VMData")
        case .stopping:
            return NSLocalizedString("Stopping", comment: "VMData")
        case .saving:
            return NSLocalizedString("Saving", comment: "VMData")
        case .restoring:
            return NSLocalizedString("Restoring", comment: "VMData")
        }
    }
    
    /// If non-null, is the most recent screenshot image of the running VM
    var screenshotImage: PlatformImage? {
        wrapped?.screenshot?.image
    }
}

#if WITH_REMOTE
@MainActor
class VMRemoteData: VMData {
    private var backend: UTMBackend
    private var _isShortcut: Bool
    override var isShortcut: Bool {
        _isShortcut
    }
    private var initialState: UTMVirtualMachineState
    private var existingWrapped: UTMRemoteSpiceVirtualMachine?

    /// Set by caller when VM is unavailable and there is a reason for it.
    @Published var unavailableReason: String?

    init(fromRemoteItem item: UTMRemoteMessageServer.VirtualMachineInformation, existingWrapped: UTMRemoteSpiceVirtualMachine? = nil) {
        self.backend = item.backend
        self._isShortcut = item.isShortcut
        self.initialState = item.state
        self.existingWrapped = existingWrapped
        super.init()
        self.isTakeoverAllowed = item.isTakeoverAllowed
        self.registryEntryWrapped = UTMRegistry.shared.entry(uuid: item.id, name: item.name, path: item.path)
        self.registryEntryWrapped!.isSuspended = item.isSuspended
        self.registryEntryWrapped!.externalDrives = item.mountedDrives.mapValues({ UTMRegistryEntry.File(dummyFromPath: $0) })
    }

    override func load() throws {
        throw VMRemoteDataError.notImplemented
    }

    func load(withRemoteServer server: UTMRemoteClient.Remote) async throws {
        guard backend == .qemu else {
            throw VMRemoteDataError.backendNotSupported
        }
        let entry = registryEntryWrapped!
        let config = try await server.getQEMUConfiguration(for: entry.uuid)
        await loadCustomIcon(withRemoteServer: server, id: entry.uuid, config: config)
        let vm: UTMRemoteSpiceVirtualMachine
        if let existingWrapped = existingWrapped {
            vm = existingWrapped
            wrapped = vm
            self.existingWrapped = nil
            await reloadConfiguration(withRemoteServer: server, config: config)
            vm.updateRegistry(entry)
        } else {
            vm = UTMRemoteSpiceVirtualMachine(forRemoteServer: server, remotePath: entry.package.path, entry: entry, config: config)
            wrapped = vm
        }
        vm.updateConfigFromRegistry()
        subscribeToChildren()
        await vm.updateRemoteState(initialState)
    }

    func reloadConfiguration(withRemoteServer server: UTMRemoteClient.Remote, config: UTMQemuConfiguration) async {
        let spiceVM = wrapped as! UTMRemoteSpiceVirtualMachine
        await loadCustomIcon(withRemoteServer: server, id: spiceVM.id, config: config)
        spiceVM.reload(usingConfiguration: config)
    }

    private func loadCustomIcon(withRemoteServer server: UTMRemoteClient.Remote, id: UUID, config: UTMQemuConfiguration) async {
        if config.information.isIconCustom, let iconUrl = config.information.iconURL {
            if let iconUrl = try? await server.getPackageFile(for: id, relativePathComponents: [UTMQemuConfiguration.dataDirectoryName, iconUrl.lastPathComponent]) {
                config.information.iconURL = iconUrl
            }
        }
    }

    func updateMountedDrives(_ mountedDrives: [String: String]) {
        guard let registryEntry = registryEntry else {
            return
        }
        registryEntry.externalDrives = mountedDrives.mapValues({ UTMRegistryEntry.File(dummyFromPath: $0) })
    }
}

enum VMRemoteDataError: Error {
    case notImplemented
    case backendNotSupported
}

extension VMRemoteDataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return NSLocalizedString("This function is not implemented.", comment: "VMData")
        case .backendNotSupported:
            return NSLocalizedString("This VM is not available or is configured for a backend that does not support remote clients.", comment: "VMData")
        }
    }
}
#endif
