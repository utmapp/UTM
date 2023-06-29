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
    private(set) var wrapped: (any UTMVirtualMachine)? {
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
    private var registryEntryWrapped: UTMRegistryEntry?
    
    /// Set when we use a temporary UUID because we loaded a legacy entry
    private var uuidUnknown: Bool = false
    
    /// Display VM as "deleted" for UI elements
    ///
    /// This is a workaround for SwiftUI bugs not hiding deleted elements.
    @Published var isDeleted: Bool = false
    
    /// Copy from wrapped VM
    @Published var state: UTMVirtualMachineState = .stopped
    
    /// Copy from wrapped VM
    @Published var screenshot: PlatformImage?
    
    /// Allows changes in the config, registry, and VM to be reflected
    private var observers: [AnyCancellable] = []
    
    /// No default init
    private init() {
        
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
        if let qemuConfig = config as? UTMQemuConfiguration {
            wrapped = try UTMQemuVirtualMachine(newForConfiguration: qemuConfig, destinationUrl: destinationUrl)
        }
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
        if let qemuConfig = config as? UTMQemuConfiguration {
            loaded = try UTMQemuVirtualMachine(packageUrl: url, configuration: qemuConfig, isShortcut: isShortcut)
        }
        #if os(macOS)
        if let appleConfig = config as? UTMAppleConfiguration {
            loaded = try UTMAppleVirtualMachine(packageUrl: url, configuration: appleConfig, isShortcut: isShortcut)
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
    private func subscribeToChildren() {
        var s: [AnyCancellable] = []
        if let wrapped = wrapped {
            wrapped.onConfigurationChange = { [weak self] in
                self?.subscribeToChildren()
                self?.objectWillChange.send()
            }
            
            wrapped.onStateChange = { [weak self] in
                guard let self = self else {
                    return
                }
                Task { @MainActor in
                    self.state = wrapped.state
                    self.screenshot = wrapped.screenshot
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
    /// True if the .utm is loaded outside of the default storage
    var isShortcut: Bool {
        let defaultStorageUrl = UTMData.defaultStorageUrl.standardizedFileURL
        let parentUrl = pathUrl.deletingLastPathComponent().standardizedFileURL
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
            if registryEntry?.hasSaveState == true {
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
        wrapped?.screenshot
    }
}
