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
    private(set) var wrapped: UTMVirtualMachine? {
        willSet {
            objectWillChange.send()
        }
        
        didSet {
            subscribeToChildren()
        }
    }
    
    /// Virtual machine configuration
    var config: (any UTMConfiguration)? {
        wrapped?.config.wrappedValue as? (any UTMConfiguration)
    }
    
    /// Current path of the VM
    var pathUrl: URL {
        if let wrapped = wrapped {
            return wrapped.path
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
    
    /// Allows changes in the config, registry, and VM to be reflected
    private var observers: [AnyCancellable] = []
    
    /// No default init
    private init() {
        
    }
    
    /// Create a VM from an existing object
    /// - Parameter vm: VM to wrap
    convenience init(wrapping vm: UTMVirtualMachine) {
        self.init()
        self.wrapped = vm
        subscribeToChildren()
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
    convenience init<Config: UTMConfiguration>(creatingFromConfig config: Config, destinationUrl: URL) {
        self.init()
        if config is UTMQemuConfiguration {
            wrapped = UTMQemuVirtualMachine(newConfig: config, destinationURL: destinationUrl)
        }
        #if os(macOS)
        if config is UTMAppleConfiguration {
            wrapped = UTMAppleVirtualMachine(newConfig: config, destinationURL: destinationUrl)
        }
        #endif
        subscribeToChildren()
    }
    
    /// Loads the VM from file
    ///
    /// If the VM is already loaded, it will return true without doing anything.
    /// - Returns: If load was successful
    func load() throws {
        guard !isLoaded else {
            return
        }
        guard let vm = UTMVirtualMachine(url: pathUrl) else {
            throw VMDataError.virtualMachineNotLoaded
        }
        vm.isShortcut = isShortcut
        if let oldEntry = registryEntry, oldEntry.uuid != vm.registryEntry.uuid {
            if uuidUnknown {
                // legacy VMs don't have UUID stored so we made a fake UUID
                UTMRegistry.shared.remove(entry: oldEntry)
            } else {
                // persistent uuid does not match indicating a cloned or legacy VM with a duplicate UUID
                vm.changeUuid(to: oldEntry.uuid, copyFromExisting: oldEntry)
            }
        }
        wrapped = vm
        uuidUnknown = false
    }
    
    /// Saves the VM to file
    func save() async throws {
        guard let wrapped = wrapped else {
            throw VMDataError.virtualMachineNotLoaded
        }
        try await wrapped.saveUTM()
    }
    
    /// Listen to changes in the underlying object and propogate upwards
    private func subscribeToChildren() {
        var s: [AnyCancellable] = []
        if let config = config as? UTMQemuConfiguration {
            s.append(config.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            })
        }
        #if os(macOS)
        if let config = config as? UTMAppleConfiguration {
            s.append(config.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            })
        }
        #endif
        if let registryEntry = registryEntry {
            s.append(registryEntry.objectWillChange.sink { [weak self] in
                guard let self = self else {
                    return
                }
                self.objectWillChange.send()
                self.wrapped?.updateConfigFromRegistry()
            })
        }
        // observe KVO publisher for state changes
        if let wrapped = wrapped {
            s.append(wrapped.publisher(for: \.state).sink { [weak self] _ in
                self?.objectWillChange.send()
            })
            s.append(wrapped.publisher(for: \.screenshot).sink { [weak self] _ in
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
            return lhs.wrapped == rhs.wrapped
        }
        if let lhsEntry = lhs.registryEntryWrapped, let rhsEntry = rhs.registryEntryWrapped {
            return lhsEntry == rhsEntry
        }
        return false
    }
}

extension VMData: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(wrapped)
        hasher.combine(registryEntryWrapped)
        hasher.combine(isDeleted)
    }
}

// MARK: - VM State
extension VMData {
    /// True if the .utm is loaded outside of the default storage
    var isShortcut: Bool {
        if let wrapped = wrapped {
            return wrapped.isShortcut
        } else {
            let defaultStorageUrl = UTMData.defaultStorageUrl.standardizedFileURL
            let parentUrl = pathUrl.deletingLastPathComponent().standardizedFileURL
            return parentUrl != defaultStorageUrl
        }
    }
    
    /// VM is loaded
    var isLoaded: Bool {
        wrapped != nil
    }
    
    /// VM is stopped
    var isStopped: Bool {
        if let state = wrapped?.state {
            return state == .vmStopped || state == .vmPaused
        } else {
            return true
        }
    }
    
    /// VM can be modified
    var isModifyAllowed: Bool {
        if let state = wrapped?.state {
            return state == .vmStopped
        } else {
            return false
        }
    }
    
    /// Display VM as "busy" for UI elements
    var isBusy: Bool {
        wrapped?.state == .vmPausing ||
        wrapped?.state == .vmResuming ||
        wrapped?.state == .vmStarting ||
        wrapped?.state == .vmStopping
    }
    
    /// VM has been suspended before
    var hasSuspendState: Bool {
        registryEntry?.isSuspended ?? false
    }
}

// MARK: - Home UI elements
extension VMData {
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
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
        guard let state = wrapped?.state else {
            return unavailable
        }
        switch state {
        case .vmStopped:
            if registryEntry?.hasSaveState == true {
                return NSLocalizedString("Suspended", comment: "VMData");
            } else {
                return NSLocalizedString("Stopped", comment: "VMData");
            }
        case .vmStarting:
            return NSLocalizedString("Starting", comment: "VMData")
        case .vmStarted:
            return NSLocalizedString("Started", comment: "VMData")
        case .vmPausing:
            return NSLocalizedString("Pausing", comment: "VMData")
        case .vmPaused:
            return NSLocalizedString("Paused", comment: "VMData")
        case .vmResuming:
            return NSLocalizedString("Resuming", comment: "VMData")
        case .vmStopping:
            return NSLocalizedString("Stopping", comment: "VMData")
        @unknown default:
            fatalError()
        }
    }
    
    /// If non-null, is the most recent screenshot image of the running VM
    var screenshotImage: PlatformImage? {
        wrapped?.screenshot?.image
    }
}
