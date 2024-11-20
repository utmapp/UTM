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

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
import SwiftUI
#endif
#if canImport(AltKit) && WITH_JIT
import AltKit
#endif
#if WITH_SERVER
import Combine
#endif
import SwiftCopyfile

#if WITH_REMOTE
import CocoaSpiceNoUsb
typealias ConcreteVirtualMachine = UTMRemoteSpiceVirtualMachine
#else
typealias ConcreteVirtualMachine = UTMQemuVirtualMachine
#endif

enum AlertItem: Identifiable {
    case message(String)
    case downloadUrl(URL)

    var id: Int {
        switch self {
        case .downloadUrl(let url):
            return url.hashValue
        case .message(let message):
            return message.hashValue
        }
    }
}

@MainActor class UTMData: ObservableObject {
    
    /// Sandbox location for storing .utm bundles
    nonisolated static var defaultStorageUrl: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// View: show VM settings
    @Published var showSettingsModal: Bool
    
    /// View: show new VM wizard
    @Published var showNewVMSheet: Bool
    
    /// View: show an alert message
    @Published var alertItem: AlertItem?

    /// View: show busy spinner
    @Published var busy: Bool
    
    /// View: show a percent progress in the busy spinner
    @Published var busyProgress: Float?

    /// View: currently selected VM
    @Published var selectedVM: VMData?
    
    /// View: all VMs listed, we save a bookmark to each when array is modified
    @Published private(set) var virtualMachines: [VMData] {
        didSet {
            listSaveToDefaults()
        }
    }
    
    /// View: all pending VMs listed (ZIP and IPSW downloads)
    @Published private(set) var pendingVMs: [UTMPendingVirtualMachine]
    
    #if os(macOS)
    /// View controller for every VM currently active
    var vmWindows: [VMData: Any] = [:]
    #else
    /// View controller for currently active VM
    var vmVC: Any?
    
    /// View state for active VM primary display
    @State var vmPrimaryWindowState: VMWindowState?
    #endif
    
    /// Shortcut for accessing FileManager.default
    nonisolated private var fileManager: FileManager {
        FileManager.default
    }
    
    /// Shortcut for accessing storage URL from instance
    nonisolated private var documentsURL: URL {
        UTMData.defaultStorageUrl
    }

    #if WITH_SERVER
    /// Remote access server
    private(set) var remoteServer: UTMRemoteServer!

    /// Listeners for remote access
    private var remoteChangeListeners: [VMData: Set<AnyCancellable>] = [:]

    /// Listener for list changes
    private var listChangedListener: AnyCancellable?
    #endif

    /// Queue to run `busyWork` tasks
    private var busyQueue: DispatchQueue
    
    init() {
        self.busyQueue = DispatchQueue(label: "UTM Busy Queue", qos: .userInitiated)
        self.showSettingsModal = false
        self.showNewVMSheet = false
        self.busy = false
        self.virtualMachines = []
        self.pendingVMs = []
        self.selectedVM = nil
        #if WITH_SERVER
        self.remoteServer = UTMRemoteServer(data: self)
        beginObservingChanges()
        #endif
        listLoadFromDefaults()
    }
    
    // MARK: - VM listing
    
    /// Re-loads UTM bundles from default path
    ///
    /// This removes stale entries (deleted/not accessible) and duplicate entries
    func listRefresh() async {
        // create Documents directory if it doesn't exist
        if !fileManager.fileExists(atPath: Self.defaultStorageUrl.path) {
            try? fileManager.createDirectory(at: Self.defaultStorageUrl, withIntermediateDirectories: false)
        }
        // wrap stale VMs
        var list = virtualMachines
        for i in list.indices.reversed() {
            let vm = list[i]
            if let registryEntry = vm.registryEntry, !fileManager.fileExists(atPath: registryEntry.package.path) {
                list[i] = VMData(from: registryEntry)
            }
        }
        // now look for and add new VMs in default storage
        do {
            let files = try fileManager.contentsOfDirectory(at: UTMData.defaultStorageUrl, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            let newFiles = files.filter { newFile in
                !list.contains { existingVM in
                    existingVM.pathUrl.standardizedFileURL == newFile.standardizedFileURL
                }
            }
            for file in newFiles {
                guard try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false else {
                    continue
                }
                guard ConcreteVirtualMachine.isVirtualMachine(url: file) else {
                    continue
                }
                await Task.yield()
                if let vm = try? VMData(url: file) {
                    if uuidHasCollision(with: vm, in: list) {
                        if let index = list.firstIndex(where: { !$0.isLoaded && $0.id == vm.id }) {
                            // we have a stale VM with the same UUID, so we replace that entry with this one
                            list[index] = vm
                            // update the registry with the new bookmark
                            try? await vm.wrapped!.updateRegistryFromConfig()
                            continue
                        } else {
                            // duplicate is not stale so we need a new UUID
                            uuidRegenerate(for: vm)
                        }
                    }
                    list.insert(vm, at: 0)
                } else {
                    logger.error("Failed to create object for \(file)")
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        // replace the VM list with our new one
        if virtualMachines != list {
            listReplace(with: list)
        }
        // prune the registry
        let uuids = list.compactMap({ $0.registryEntry?.uuid.uuidString })
        UTMRegistry.shared.prune(exceptFor: Set(uuids))
    }
    
    /// Load VM list (and order) from persistent storage
    fileprivate func listLoadFromDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "VMList") == nil else {
            listLegacyLoadFromDefaults()
            // fix collisions
            for vm in virtualMachines {
                if uuidHasCollision(with: vm) {
                    uuidRegenerate(for: vm)
                }
            }
            // delete legacy
            defaults.removeObject(forKey: "VMList")
            return
        }
        // registry entry list
        guard let list = defaults.stringArray(forKey: "VMEntryList") else {
            return
        }
        let virtualMachines: [VMData] = list.uniqued().compactMap { uuidString in
            guard let entry = UTMRegistry.shared.entry(for: uuidString) else {
                return nil
            }
            let vm = VMData(from: entry)
            do {
                try vm.load()
            } catch {
                logger.error("Error loading '\(entry.uuid)': \(error)")
            }
            return vm
        }
        listReplace(with: virtualMachines)
    }
    
    /// Load VM list (and order) from persistent storage (legacy)
    private func listLegacyLoadFromDefaults() {
        let defaults = UserDefaults.standard
        // legacy path list
        if let files = defaults.array(forKey: "VMList") as? [String] {
            let virtualMachines = files.uniqued().compactMap({ file in
                let url = documentsURL.appendingPathComponent(file, isDirectory: true)
                if let vm = try? VMData(url: url) {
                    return vm
                } else {
                    return nil
                }
            })
            listReplace(with: virtualMachines)
        }
        // bookmark list
        if let list = defaults.array(forKey: "VMList") {
            let virtualMachines = list.compactMap { item in
                let vm: VMData?
                if let bookmark = item as? Data {
                    vm = VMData(bookmark: bookmark)
                } else if let dict = item as? [String: Any] {
                    vm = VMData(from: dict)
                } else {
                    vm = nil
                }
                try? vm?.load()
                return vm
            }
            listReplace(with: virtualMachines)
        }
    }
    
    /// Save VM list (and order) to persistent storage
    private func listSaveToDefaults() {
        let defaults = UserDefaults.standard
        let wrappedVMs = virtualMachines.map { $0.id.uuidString }
        defaults.set(wrappedVMs, forKey: "VMEntryList")
    }
    
    /// Replace current VM list with a new list
    /// - Parameter vms: List to replace with
    fileprivate func listReplace(with vms: [VMData]) {
        virtualMachines.forEach({ endObservingChanges(for: $0) })
        virtualMachines = vms
        vms.forEach({ beginObservingChanges(for: $0) })
        if let vm = selectedVM, !vms.contains(where: { $0 == vm }) {
            selectedVM = nil
        }
    }
    
    /// Add VM to list
    /// - Parameter vm: VM to add
    /// - Parameter at: Optional index to add to, otherwise will be added to the end
    private func listAdd(vm: VMData, at index: Int? = nil) {
        if uuidHasCollision(with: vm) {
            uuidRegenerate(for: vm)
        }
        if let index = index {
            virtualMachines.insert(vm, at: index)
        } else {
            virtualMachines.append(vm)
        }
        beginObservingChanges(for: vm)
    }
    
    /// Select VM in list
    /// - Parameter vm: VM to select
    public func listSelect(vm: VMData) {
        selectedVM = vm
    }
    
    /// Remove a VM from list
    /// - Parameter vm: VM to remove
    /// - Returns: Index of item removed or nil if already removed
    @discardableResult public func listRemove(vm: VMData) -> Int? {
        let index = virtualMachines.firstIndex(of: vm)
        endObservingChanges(for: vm)
        if let index = index {
            virtualMachines.remove(at: index)
        }
        if vm == selectedVM {
            selectedVM = nil
        }
        vm.isDeleted = true // alert views to update
        return index
    }
    
    /// Add pending VM to list
    /// - Parameter pendingVM: Pending VM to add
    /// - Parameter at: Optional index to add to, otherwise will be added to the end
    private func listAdd(pendingVM: UTMPendingVirtualMachine, at index: Int? = nil) {
        if let index = index {
            pendingVMs.insert(pendingVM, at: index)
        } else {
            pendingVMs.append(pendingVM)
        }
    }
    
    /// Remove pending VM from list
    /// - Parameter pendingVM: Pending VM to remove
    /// - Returns: Index of item removed or nil if already removed
    @discardableResult private func listRemove(pendingVM: UTMPendingVirtualMachine) -> Int? {
        let index = pendingVMs.firstIndex(where: { $0.id == pendingVM.id })
        if let index = index {
            pendingVMs.remove(at: index)
        }
        return index
    }
    
    /// Move items in VM list
    /// - Parameters:
    ///   - fromOffsets: Offsets from move from
    ///   - toOffset: Offsets to move to
    func listMove(fromOffsets: IndexSet, toOffset: Int) {
        virtualMachines.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    // MARK: - New name
    
    /// Generate a unique VM name
    /// - Parameter base: Base name
    /// - Returns: Unique name for a non-existing item in the default storage path
    nonisolated func newDefaultVMName(base: String = NSLocalizedString("Virtual Machine", comment: "UTMData")) -> String {
        let nameForId = { (i: Int) in i <= 1 ? base : "\(base) \(i)" }
        for i in 1..<1000 {
            let name = nameForId(i)
            let file = ConcreteVirtualMachine.virtualMachinePath(for: name, in: documentsURL)
            if !fileManager.fileExists(atPath: file.path) {
                return name
            }
        }
        return ProcessInfo.processInfo.globallyUniqueString
    }
    
    /// Generate a filename for an imported file, avoiding duplicate names
    /// - Parameters:
    ///   - sourceUrl: Source image where name will come from
    ///   - destUrl: Destination directory where duplicates will be checked
    ///   - withExtension: Optionally change the file extension
    /// - Returns: Unique filename that is not used in the destUrl
    nonisolated static func newImage(from sourceUrl: URL, to destUrl: URL, withExtension: String? = nil) -> URL {
        let name = sourceUrl.deletingPathExtension().lastPathComponent
        let ext = withExtension ?? sourceUrl.pathExtension
        let strFromInt = { (i: Int) in i == 1 ? "" : "-\(i)" }
        for i in 1..<1000 {
            let attempt = "\(name)\(strFromInt(i))"
            let attemptUrl = destUrl.appendingPathComponent(attempt).appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: attemptUrl.path) {
                return attemptUrl
            }
        }
        repeat {
            let attempt = UUID().uuidString
            let attemptUrl = destUrl.appendingPathComponent(attempt).appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: attemptUrl.path) {
                return attemptUrl
            }
        } while true
    }
    
    // MARK: - Other view states
    
    private func setBusyIndicator(_ busy: Bool) {
        self.busy = busy
    }
    
    func showErrorAlert(message: String) {
        alertItem = .message(message)
    }
    
    func newVM() {
        showSettingsModal = false
        showNewVMSheet = true
    }
    
    func showSettingsForCurrentVM() {
        #if os(iOS) || os(visionOS)
        // SwiftUI bug: cannot show modal at the same time as changing selected VM or it breaks
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.showSettingsModal = true
        }
        #else
        showSettingsModal = true
        #endif
    }
    
    // MARK: - VM operations
    
    /// Save an existing VM to disk
    /// - Parameter vm: VM to save
    func save(vm: VMData) async throws {
        do {
            try await vm.save()
            #if WITH_SERVER
            if let qemuConfig = vm.config as? UTMQemuConfiguration {
                await remoteServer.broadcast { remote in
                    try await remote.qemuConfigurationHasChanged(id: vm.id, configuration: qemuConfig)
                }
            }
            #endif
        } catch {
            // refresh the VM object as it is now stale
            let origError = error
            do {
                try discardChanges(for: vm)
            } catch {
                // if we can't discard changes, recreate the VM from scratch
                let path = vm.pathUrl
                guard let newVM = try? VMData(url: path) else {
                    logger.debug("Cannot create new object for \(path.path)")
                    throw origError
                }
                let index = listRemove(vm: vm)
                listAdd(vm: newVM, at: index)
                listSelect(vm: newVM)
            }
            throw origError
        }
    }
    
    /// Discard changes to VM configuration
    /// - Parameter vm: VM configuration to discard
    func discardChanges(for vm: VMData) throws {
        if let wrapped = vm.wrapped {
            try wrapped.reload(from: nil)
            if uuidHasCollision(with: vm) {
                wrapped.changeUuid(to: UUID(), name: nil, copyingEntry: vm.registryEntry)
            }
        }
    }
    
    /// Save a new VM to disk
    /// - Parameters:
    ///   - config: New VM configuration
    func create<Config: UTMConfiguration>(config: Config) async throws -> VMData {
        guard !virtualMachines.contains(where: { !$0.isShortcut && $0.config?.information.name == config.information.name }) else {
            throw UTMDataError.virtualMachineAlreadyExists
        }
        let vm = try VMData(creatingFromConfig: config, destinationUrl: Self.defaultStorageUrl)
        do {
            try await save(vm: vm)
        } catch {
            if isDirectoryEmpty(vm.pathUrl) {
                try? fileManager.removeItem(at: vm.pathUrl)
            }
            throw error
        }
        listAdd(vm: vm)
        listSelect(vm: vm)
        return vm
    }
    
    /// Delete a VM from disk
    /// - Parameter vm: VM to delete
    /// - Returns: Index of item removed in VM list or nil if not in list
    @discardableResult func delete(vm: VMData, alsoRegistry: Bool = true) async throws -> Int? {
        if vm.isLoaded {
            try fileManager.removeItem(at: vm.pathUrl)
        }
        
        // close any open window
        close(vm: vm)
        
        if alsoRegistry, let registryEntry = vm.registryEntry {
            UTMRegistry.shared.remove(entry: registryEntry)
        }
        return listRemove(vm: vm)
    }
    
    /// Save a copy of the VM and all data to default storage location
    /// - Parameter vm: VM to clone
    /// - Returns: The new VM
    @discardableResult func clone(vm: VMData) async throws -> VMData {
        let newName: String = newDefaultVMName(base: vm.detailsTitleLabel)
        let newPath = ConcreteVirtualMachine.virtualMachinePath(for: newName, in: documentsURL)

        try await copyItemWithCopyfile(at: vm.pathUrl, to: newPath)
        guard let newVM = try? VMData(url: newPath) else {
            throw UTMDataError.cloneFailed
        }
        newVM.wrapped!.changeUuid(to: UUID(), name: newName, copyingEntry: nil)
        try await newVM.save()
        var index = virtualMachines.firstIndex(of: vm)
        if index != nil {
            index! += 1
        }
        listAdd(vm: newVM, at: index)
        listSelect(vm: newVM)
        return newVM
    }
    
    /// Save a copy of the VM and all data to arbitary location
    /// - Parameters:
    ///   - vm: VM to copy
    ///   - url: Location to copy to (must be writable)
    func export(vm: VMData, to url: URL) async throws {
        let sourceUrl = vm.pathUrl
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try await copyItemWithCopyfile(at: sourceUrl, to: url)
    }
    
    /// Save a copy of the VM and all data to arbitary location and delete the original data
    /// - Parameters:
    ///   - vm: VM to move
    ///   - url: Location to move to (must be writable)
    func move(vm: VMData, to url: URL) async throws {
        try await export(vm: vm, to: url)
        guard let newVM = try? VMData(url: url) else {
            throw UTMDataError.shortcutCreationFailed
        }
        try await newVM.wrapped!.updateRegistryFromConfig()
        
        let oldSelected = selectedVM
        let index = try await delete(vm: vm, alsoRegistry: false)
        listAdd(vm: newVM, at: index)
        if oldSelected == vm {
            listSelect(vm: newVM)
        }
    }
    
    /// Open settings modal
    /// - Parameter vm: VM to edit settings
    func edit(vm: VMData) {
        listSelect(vm: vm)
        showNewVMSheet = false
        showSettingsForCurrentVM()
    }
    
    /// Copy configuration but not data from existing VM to a new VM
    /// - Parameter vm: Existing VM to copy configuration from
    func template(vm: VMData) async throws {
        let copy = try UTMQemuConfiguration.load(from: vm.pathUrl)
        if let copy = copy as? UTMQemuConfiguration {
            copy.information.name = self.newDefaultVMName(base: copy.information.name)
            copy.information.uuid = UUID()
            copy.drives = []
            _ = try await create(config: copy)
        }
        #if os(macOS)
        if let copy = copy as? UTMAppleConfiguration {
            copy.information.name = self.newDefaultVMName(base: copy.information.name)
            copy.information.uuid = UUID()
            copy.drives = []
            _ = try await create(config: copy)
        }
        #endif
        showSettingsForCurrentVM()
    }
    
    // MARK: - File I/O related
    
    /// Calculate total size of VM and data
    /// - Parameter vm: VM to calculate size
    /// - Returns: Size in bytes
    func computeSize(for vm: VMData) async -> Int64 {
        return computeSize(recursiveFor: vm.pathUrl)
    }

    private func computeSize(recursiveFor url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else {
            logger.error("failed to create enumerator for \(url)")
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]), let size = resourceValues.totalFileAllocatedSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }
    
    /// Calculate size of a single file URL
    /// - Parameter url: File URL
    /// - Returns: Size in bytes
    func computeSize(for url: URL) -> Int64 {
        if let resourceValues = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]), let size = resourceValues.totalFileAllocatedSize {
            return Int64(size)
        } else {
            return 0
        }
    }
    
    /// Handles UTM file URLs
    ///
    /// If .utm is already in the list, select it
    /// If .utm is in the Inbox directory, move it to the default storage
    /// Otherwise we create a shortcut (default for macOS) or a copy (default for iOS)
    /// - Parameter url: File URL to read from
    /// - Parameter asShortcut: Create a shortcut rather than a copy
    func importUTM(from url: URL, asShortcut: Bool = true) async throws {
        guard url.isFileURL else { return }
        let isScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        logger.info("importing: \(url)")
        // attempt to turn temp URL to presistent bookmark early otherwise,
        // when stopAccessingSecurityScopedResource() is called, we lose access
        let bookmark = try url.persistentBookmarkData()
        let url = try URL(resolvingPersistentBookmarkData: bookmark)
        let fileBasePath = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let dest = documentsURL.appendingPathComponent(fileName, isDirectory: true)
        if let vm = virtualMachines.first(where: { vm -> Bool in
            return vm.pathUrl.standardizedFileURL == url.standardizedFileURL
        }) {
            logger.info("found existing vm!")
            if !vm.isLoaded {
                logger.info("existing vm is wrapped")
                try vm.load()
            } else {
                logger.info("existing vm is not wrapped")
                listSelect(vm: vm)
            }
            return
        }
        // check if VM is valid
        guard let _ = try? VMData(url: url) else {
            throw UTMDataError.importFailed
        }
        let vm: VMData?
        if (fileBasePath.resolvingSymlinksInPath().path == documentsURL.appendingPathComponent("Inbox", isDirectory: true).path) {
            logger.info("moving from Inbox")
            try fileManager.moveItem(at: url, to: dest)
            vm = try VMData(url: dest)
        } else if asShortcut {
            logger.info("loading as a shortcut")
            vm = try VMData(url: url)
        } else {
            logger.info("copying to Documents")
            try fileManager.copyItem(at: url, to: dest)
            vm = try VMData(url: dest)
        }
        guard let vm = vm else {
            throw UTMDataError.importParseFailed
        }
        listAdd(vm: vm)
        listSelect(vm: vm)
    }
    
    /// Handles UTM file URLs similar to importUTM, with few differences
    ///
    /// Always creates new VM (no shortcuts)
    /// Copies VM file with a unique name to default storage (to avoid duplicates)
    /// Returns VM data Object (to access UUID)
    /// - Parameter url: File URL to read from
    func importNewUTM(from url: URL) async throws -> VMData {
        guard url.isFileURL else {
            throw UTMDataError.importFailed
        }
        let isScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        logger.info("importing: \(url)")
        // attempt to turn temp URL to presistent bookmark early otherwise,
        // when stopAccessingSecurityScopedResource() is called, we lose access
        let bookmark = try url.persistentBookmarkData()
        let url = try URL(resolvingPersistentBookmarkData: bookmark)
        
        // get unique filename, for every import we create a new VM
        let newUrl = UTMData.newImage(from: url, to: documentsURL)
        let fileName = newUrl.lastPathComponent
        // create destination name (default storage + file name)
        let dest =  documentsURL.appendingPathComponent(fileName, isDirectory: true)
        
        // check if VM is valid
        guard let _ = try? VMData(url: url) else {
            throw UTMDataError.importFailed
        }
        
        // Copy file to documents
        let vm: VMData?
        logger.info("copying to Documents")
        try fileManager.copyItem(at: url, to: dest)
        vm = try VMData(url: dest)
        
        guard let vm = vm else {
            throw UTMDataError.importParseFailed
        }

        // Add vm to the list
        listAdd(vm: vm)
        listSelect(vm: vm)
        
        return vm
    }

    private func copyItemWithCopyfile(at srcURL: URL, to dstURL: URL) async throws {
        let totalSize = computeSize(recursiveFor: srcURL)
        var lastUpdate = Date()
        var lastProgress: CopyManager.Progress?
        var copiedSize: Int64 = 0
        defer {
            busyProgress = nil
        }
        for try await progress in CopyManager.default.copyItemProgress(at: srcURL, to: dstURL, flags: [.all, .recursive, .clone, .dataSparse]) {
            if let _lastProgress = lastProgress, _lastProgress.srcPath != _lastProgress.srcPath {
                copiedSize += _lastProgress.bytesCopied
                lastProgress = progress
            } else {
                lastProgress = progress
            }
            if totalSize > 0 && lastUpdate.timeIntervalSinceNow < -1 {
                lastUpdate = Date()
                let completed = Float(copiedSize + progress.bytesCopied) / Float(totalSize)
                busyProgress = completed > 1.0 ? 1.0 : completed
            }
        }
    }

    private func isDirectoryEmpty(_ pathURL: URL) -> Bool {
        guard let enumerator = fileManager.enumerator(at: pathURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return false
        }
        for case let itemURL as URL in enumerator {
            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if !isDirectory {
                return false
            }
        }
        // if we get here, we only found empty directories
        return true
    }

    // MARK: - Downloading VMs
    
    #if os(macOS) && arch(arm64)
    /// Create a new VM using configuration and downloaded IPSW
    /// - Parameter config: Apple VM configuration
    @available(macOS 12, *)
    func downloadIPSW(using config: UTMAppleConfiguration) async {
        let task = UTMDownloadIPSWTask(for: config)
        guard !virtualMachines.contains(where: { !$0.isShortcut && $0.config?.information.name == config.information.name }) else {
            showErrorAlert(message: NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData"))
            return
        }
        listAdd(pendingVM: task.pendingVM)
        Task {
            do {
                if let wrapped = try await task.download() {
                    let vm = VMData(wrapping: wrapped)
                    try await self.save(vm: vm)
                    listAdd(vm: vm)
                }
            } catch {
                showErrorAlert(message: error.localizedDescription)
            }
            listRemove(pendingVM: task.pendingVM)
        }
    }
    #endif

    /// Create a new VM by downloading a .zip and extracting it
    /// - Parameter components: Download URL components
    func downloadUTMZip(from url: URL) {
        let task = UTMDownloadVMTask(for: url)
        listAdd(pendingVM: task.pendingVM)
        Task {
            do {
                if let wrapped = try await task.download() {
                    let vm = VMData(wrapping: wrapped)
                    try await self.save(vm: vm)
                    listAdd(vm: vm)
                }
            } catch {
                showErrorAlert(message: error.localizedDescription)
            }
            listRemove(pendingVM: task.pendingVM)
        }
    }

    private func mountWindowsSupportTools(for vm: any UTMSpiceVirtualMachine) async throws {
        let task = UTMDownloadSupportToolsTask(for: vm)
        if await task.hasExistingSupportTools {
            vm.config.qemu.isGuestToolsInstallRequested = false
            _ = try await task.mountTools()
        } else {
            listAdd(pendingVM: task.pendingVM)
            Task {
                do {
                    _ = try await task.download()
                } catch {
                    showErrorAlert(message: error.localizedDescription)
                }
                vm.config.qemu.isGuestToolsInstallRequested = false
                listRemove(pendingVM: task.pendingVM)
            }
        }
    }

    #if os(macOS)
    @available(macOS 15, *)
    private func mountMacSupportTools(for vm: UTMAppleVirtualMachine) async throws {
        let task = UTMDownloadMacSupportToolsTask(for: vm)
        if await task.hasExistingSupportTools {
            vm.config.isGuestToolsInstallRequested = false
            _ = try await task.mountTools()
        } else {
            listAdd(pendingVM: task.pendingVM)
            Task {
                do {
                    _ = try await task.download()
                } catch {
                    showErrorAlert(message: error.localizedDescription)
                }
                vm.config.isGuestToolsInstallRequested = false
                listRemove(pendingVM: task.pendingVM)
            }
        }
    }
    #endif

    func mountSupportTools(for vm: any UTMVirtualMachine) async throws {
        if let vm = vm as? any UTMSpiceVirtualMachine {
            return try await mountWindowsSupportTools(for: vm)
        }
        #if os(macOS)
        if #available(macOS 15, *), let vm = vm as? UTMAppleVirtualMachine, vm.config.system.boot.operatingSystem == .macOS {
            return try await mountMacSupportTools(for: vm)
        }
        #endif
        throw UTMDataError.unsupportedBackend
    }
    
    /// Cancel a download and discard any data
    /// - Parameter pendingVM: Pending VM to cancel
    func cancelDownload(for pendingVM: UTMPendingVirtualMachine) {
        pendingVM.cancel()
    }
    
    // MARK: - Reclaim space
    
    #if os(macOS)
    /// Reclaim empty space in a file by (re)-converting it to QCOW2
    ///
    /// This will overwrite driveUrl with the converted file on success!
    /// - Parameter driveUrl: Original drive to convert
    /// - Parameter isCompressed: Compress existing data
    func reclaimSpace(for driveUrl: URL, withCompression isCompressed: Bool = false) async throws {
        let baseUrl = driveUrl.deletingLastPathComponent()
        let dstUrl = Self.newImage(from: driveUrl, to: baseUrl, withExtension: "qcow2")
        defer {
            busyProgress = nil
        }
        try await UTMQemuImage.convert(from: driveUrl, toQcow2: dstUrl, withCompression: isCompressed) { progress in
            Task { @MainActor in
                self.busyProgress = progress / 100
            }
        }
        busyProgress = nil
        do {
            try fileManager.replaceItem(at: driveUrl, withItemAt: dstUrl, backupItemName: nil, resultingItemURL: nil)
        } catch {
            // on failure delete the converted file
            try? fileManager.removeItem(at: dstUrl)
            throw error
        }
    }
    
    func qcow2DriveSize(for driveUrl: URL) async -> Int64 {
        return (try? await UTMQemuImage.size(image: driveUrl)) ?? 0
    }

    func resizeQcow2Drive(for driveUrl: URL, sizeInMib: Int) async throws {
        let bytesinMib = 1048576
        try await UTMQemuImage.resize(image: driveUrl, size: UInt64(sizeInMib * bytesinMib))
    }
    #endif
    
    // MARK: - UUID migration
    
    private func uuidHasCollision(with vm: VMData) -> Bool {
        return uuidHasCollision(with: vm, in: virtualMachines)
    }
    
    private func uuidHasCollision(with vm: VMData, in list: [VMData]) -> Bool {
        for otherVM in list {
            if otherVM == vm {
                return false
            } else if let lhs = otherVM.registryEntry?.uuid, let rhs = vm.registryEntry?.uuid, lhs == rhs {
                return true
            }
        }
        return false
    }
    
    private func uuidRegenerate(for vm: VMData) {
        guard let vm = vm.wrapped else {
            return
        }
        vm.changeUuid(to: UUID(), name: nil, copyingEntry: vm.registryEntry)
    }

    // MARK: - Change listener

    private func beginObservingChanges() {
        #if WITH_SERVER
        listChangedListener = $virtualMachines.sink { vms in
            Task {
                await self.remoteServer.broadcast { remote in
                    try await remote.listHasChanged(ids: vms.map({ $0.id }))
                }
            }
        }
        #endif
    }

    private func beginObservingChanges(for vm: VMData) {
        #if WITH_SERVER
        var observers = Set<AnyCancellable>()
        let registryEntry = vm.registryEntry
        observers.insert(vm.objectWillChange.sink { [self] _ in
            // reset observers when registry changes
            if vm.registryEntry != registryEntry {
                endObservingChanges(for: vm)
                beginObservingChanges(for: vm)
            }
        })
        observers.insert(vm.$state.sink { state in
            Task {
                let isTakeoverAllowed = self.vmWindows[vm] is VMRemoteSessionState && (state == .started || state == .paused)
                await self.remoteServer.broadcast { remote in
                    try await remote.virtualMachine(id: vm.id, didTransitionToState: state, isTakeoverAllowed: isTakeoverAllowed)
                }
            }
        })
        if let registryEntry = registryEntry {
            observers.insert(registryEntry.externalDrivePublisher.sink { drives in
                let mountedDrives = drives.mapValues({ $0.path })
                Task {
                    await self.remoteServer.broadcast { remote in
                        try await remote.mountedDrivesHasChanged(id: vm.id, mountedDrives: mountedDrives)
                    }
                }
            })
        }
        remoteChangeListeners[vm] = observers
        #endif
    }

    private func endObservingChanges(for vm: VMData) {
        #if WITH_SERVER
        remoteChangeListeners.removeValue(forKey: vm)
        #endif
    }

    // MARK: - Other utility functions
    
    /// In some regions, iOS will prompt the user for network access
    func triggeriOSNetworkAccessPrompt() {
        let task = URLSession.shared.dataTask(with: URL(string: "http://captive.apple.com")!)
        task.resume()
    }
    
    /// Execute a task with spinning progress indicator
    /// - Parameter work: Function to execute
    func busyWork(_ work: @escaping () throws -> Void) {
        busyQueue.async {
            DispatchQueue.main.async {
                self.busy = true
            }
            defer {
                DispatchQueue.main.async {
                    self.busy = false
                }
            }
            do {
                try work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertItem = .message(error.localizedDescription)
                }
            }
        }
    }
    
    /// Execute a task with spinning progress indicator (Swift concurrency version)
    /// - Parameter work: Function to execute
    @discardableResult
    func busyWorkAsync<T>(_ work: @escaping @Sendable () async throws -> T) -> Task<T, any Error> {
        Task.detached(priority: .userInitiated) {
            await self.setBusyIndicator(true)
            do {
                let result = try await work()
                await self.setBusyIndicator(false)
                return result
            } catch {
                logger.error("\(error)")
                await self.showErrorAlert(message: error.localizedDescription)
                await self.setBusyIndicator(false)
                throw error
            }
        }
    }

    // MARK: - AltKit
    
#if canImport(AltKit) && WITH_JIT
    /// Detect if we are installed from AltStore and can use AltJIT
    var isAltServerCompatible: Bool {
        guard let _ = Bundle.main.infoDictionary?["ALTServerID"] else {
            return false
        }
        guard let _ = Bundle.main.infoDictionary?["ALTDeviceID"] else {
            return false
        }
        return true
    }
    
    /// Find and run AltJIT to enable JIT
    func startAltJIT() throws {
        let event = DispatchSemaphore(value: 0)
        var connectError: Error?
        DispatchQueue.main.async {
            ServerManager.shared.autoconnect { result in
                switch result
                {
                case .failure(let error):
                    logger.error("Could not auto-connect to server. \(error.localizedDescription)")
                    connectError = error
                    event.signal()
                case .success(let connection):
                    connection.enableUnsignedCodeExecution { result in
                        switch result
                        {
                        case .failure(let error):
                            logger.error("Could not enable JIT compilation. \(error.localizedDescription)")
                            connectError = error
                        case .success:
                            logger.debug("Successfully enabled JIT compilation!")
                            Main.jitAvailable = true
                        }
                        
                        connection.disconnect()
                        event.signal()
                    }
                }
            }
            ServerManager.shared.startDiscovering()
        }
        defer {
            ServerManager.shared.stopDiscovering()
        }
        if event.wait(timeout: .now() + 10) == .timedOut {
            throw UTMDataError.altServerNotFound
        } else if let error = connectError {
            throw UTMDataError.altJitError(error.localizedDescription)
        }
    }
#endif

    // MARK - JitStreamer

#if os(iOS) || os(visionOS)
    @available(iOS 15, *)
    func jitStreamerAttach() async throws {
        let urlString = String(
            format: "http://%@/attach/%ld/",
            UserDefaults.standard.string(forKey: "JitStreamerAddress") ?? "",
            getpid()
        )
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "".data(using: .utf8)
            var attachError: Error?
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let attachResponse = try JSONDecoder().decode(AttachResponse.self, from: data)
                if !attachResponse.success {
                    attachError = String.localizedStringWithFormat(NSLocalizedString("Failed to attach to JitStreamer:\n%@", comment: "ContentView"), attachResponse.message)
                } else {
                    Main.jitAvailable = true
                }
            } catch is DecodingError {
                throw UTMDataError.jitStreamerDecodeFailed
            } catch {
                throw UTMDataError.jitStreamerAttachFailed
            }
            if let attachError = attachError {
                throw attachError
            }
        } else {
            throw UTMDataError.jitStreamerUrlInvalid(urlString)
        }
    }

    private struct AttachResponse: Decodable {
        var message: String
        var success: Bool
    }
#endif
}

// MARK: - Errors
enum UTMDataError: Error {
    case virtualMachineAlreadyExists
    case virtualMachineUnavailable
    case unsupportedBackend
    case cloneFailed
    case shortcutCreationFailed
    case importFailed
    case importParseFailed
    case altServerNotFound
    case altJitError(String)
    case jitStreamerDecodeFailed
    case jitStreamerAttachFailed
    case jitStreamerUrlInvalid(String)
    case notImplemented
    case reconnectFailed
}

extension UTMDataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .virtualMachineAlreadyExists:
            return NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
        case .virtualMachineUnavailable:
            return NSLocalizedString("This virtual machine is currently unavailable, make sure it is not open in another session.", comment: "UTMData")
        case .unsupportedBackend:
            return NSLocalizedString("Operation not supported by the backend.", comment: "UTMData")
        case .cloneFailed:
            return NSLocalizedString("Failed to clone VM.", comment: "UTMData")
        case .shortcutCreationFailed:
            return NSLocalizedString("Unable to add a shortcut to the new location.", comment: "UTMData")
        case .importFailed:
            return NSLocalizedString("Cannot import this VM. Either the configuration is invalid, created in a newer version of UTM, or on a platform that is incompatible with this version of UTM.", comment: "UTMData")
        case .importParseFailed:
            return NSLocalizedString("Failed to parse imported VM.", comment: "UTMData")
        case .altServerNotFound:
            return NSLocalizedString("Cannot find AltServer for JIT enable. You cannot run VMs until JIT is enabled.", comment: "UTMData")
        case .altJitError(let message):
            return String.localizedStringWithFormat(NSLocalizedString("AltJIT error: %@", comment: "UTMData"), message)
        case .jitStreamerDecodeFailed:
            return NSLocalizedString("Failed to decode JitStreamer response.", comment: "UTMData")
        case .jitStreamerAttachFailed:
            return NSLocalizedString("Failed to attach to JitStreamer.", comment: "UTMData")
        case .jitStreamerUrlInvalid(let urlString):
            return String.localizedStringWithFormat(NSLocalizedString("Invalid JitStreamer attach URL:\n%@", comment: "UTMData"), urlString)
        case .notImplemented:
            return NSLocalizedString("This functionality is not yet implemented.", comment: "UTMData")
        case .reconnectFailed:
            return NSLocalizedString("Failed to reconnect to the server.", comment: "UTMData")
        }
    }
}

// MARK: - Remote Client

/// Declare host capabilities to any remote client
struct UTMCapabilities: OptionSet, Codable {
    let rawValue: UInt

    /// If set, no trick is needed to get JIT working as the process is entitled.
    static let hasJitEntitlements = Self(rawValue: 1 << 0)

    /// If set, virtualization is supported by this host.
    static let hasHypervisorSupport = Self(rawValue: 1 << 1)
    
    /// If set, host is aarch64
    static let isAarch64 = Self(rawValue: 1 << 2)
    
    /// If set, host is x86_64
    static let isX86_64 = Self(rawValue: 1 << 3)

    static fileprivate(set) var current: Self = {
        var current = Self()
        #if WITH_JIT
        if jb_has_jit_entitlement() {
            current.insert(.hasJitEntitlements)
        }
        if jb_has_hypervisor() {
            current.insert(.hasHypervisorSupport)
        }
        #endif
        #if arch(arm64)
        current.insert(.isAarch64)
        #endif
        #if arch(x86_64)
        current.insert(.isX86_64)
        #endif
        return current
    }()
}

#if WITH_REMOTE
private let kReconnectTimeoutSeconds: UInt64 = 5

@MainActor
class UTMRemoteData: UTMData {
    /// Remote access client
    private(set) var remoteClient: UTMRemoteClient!

    override init() {
        super.init()
        self.remoteClient = UTMRemoteClient(data: self)
    }

    override func listLoadFromDefaults() {
        // do nothing since we do not load from VMList
    }

    override func listRefresh() async {
        busyWorkAsync {
            try await self.listRefreshFromRemote()
        }
    }

    func reconnect(to server: UTMRemoteClient.State.SavedServer) async throws {
        var reconnectTask: Task<UTMRemoteClient.Remote, any Error>?
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: kReconnectTimeoutSeconds * NSEC_PER_SEC)
            reconnectTask?.cancel()
        }
        reconnectTask = busyWorkAsync { [self] in
            do {
                try await remoteClient.connect(server)
            } catch is CancellationError {
                throw UTMDataError.reconnectFailed
            }
            timeoutTask.cancel()
            try await listRefreshFromRemote()
            return await remoteClient.server
        }
        // make all active sessions wait on the reconnect
        for session in VMSessionState.allActiveSessions.values {
            let vm = session.vm as! UTMRemoteSpiceVirtualMachine
            Task {
                do {
                    try await vm.reconnectServer {
                        try await reconnectTask!.value
                    }
                } catch {
                    session.stop()
                }
            }
        }
        _ = try await reconnectTask!.value
    }

    private func listRefreshFromRemote() async throws {
        if let capabilities = await self.remoteClient.server.capabilities {
            UTMCapabilities.current = capabilities
        }
        let ids = try await remoteClient.server.listVirtualMachines()
        let items = try await remoteClient.server.getVirtualMachineInformation(for: ids)
        let openSessionVms = VMSessionState.allActiveSessions.values.map({ $0.vm })
        let vms = items.map { item in
            let wrapped = openSessionVms.first(where: { $0.id == item.id }) as? UTMRemoteSpiceVirtualMachine
            return VMRemoteData(fromRemoteItem: item, existingWrapped: wrapped)
        }
        await loadVirtualMachines(vms)
    }

    private func loadVirtualMachines(_ vms: [VMData]) async {
        listReplace(with: vms)
        for vm in vms {
            let remoteVM = vm as! VMRemoteData
            if remoteVM.isLoaded {
                continue
            }
            do {
                try await remoteVM.load(withRemoteServer: remoteClient.server)
            } catch {
                remoteVM.unavailableReason = error.localizedDescription
            }
            await Task.yield()
        }
    }

    func remoteListHasChanged(ids: [UUID]) async {
        var existing = virtualMachines.reduce(into: [:]) { partialResult, vm in
            partialResult[vm.id] = vm
        }
        let new = ids.compactMap { id in
            if existing[id] == nil {
                return id
            } else {
                return nil
            }
        }
        if !new.isEmpty, let newItems = try? await remoteClient.server.getVirtualMachineInformation(for: new) {
            newItems.map({ VMRemoteData(fromRemoteItem: $0) }).forEach { vm in
                existing[vm.id] = vm
            }
        }
        let vms = ids.compactMap({ existing[$0] })
        await loadVirtualMachines(vms)
    }

    func remoteQemuConfigurationHasChanged(id: UUID, configuration: UTMQemuConfiguration) async {
        guard let vm = virtualMachines.first(where: { $0.id == id }) as? VMRemoteData else {
            return
        }
        await vm.reloadConfiguration(withRemoteServer: remoteClient.server, config: configuration)
    }

    func remoteMountedDrivesHasChanged(id: UUID, mountedDrives: [String: String]) async {
        guard let vm = virtualMachines.first(where: { $0.id == id }) as? VMRemoteData else {
            return
        }
        vm.updateMountedDrives(mountedDrives)
    }

    func remoteVirtualMachineDidTransition(id: UUID, state: UTMVirtualMachineState, isTakeoverAllowed: Bool) async {
        guard let vm = virtualMachines.first(where: { $0.id == id }) else {
            return
        }
        let remoteVM = vm as! VMRemoteData
        let wrapped = remoteVM.wrapped as! UTMRemoteSpiceVirtualMachine
        remoteVM.isTakeoverAllowed = isTakeoverAllowed
        await wrapped.updateRemoteState(state)
    }

    func remoteVirtualMachineDidError(id: UUID, message: String) async {
        if let session = VMSessionState.allActiveSessions.values.first(where: { $0.vm.id == id }) {
            session.nonfatalError = message
        }
    }

    override func listMove(fromOffsets: IndexSet, toOffset: Int) {
        let ids = fromOffsets.map({ virtualMachines[$0].id })
        Task {
            try await remoteClient.server.reorderVirtualMachines(fromIds: ids, toOffset: toOffset)
        }
        super.listMove(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    override func save(vm: VMData) async throws {
        throw UTMDataError.notImplemented
    }

    override func discardChanges(for vm: VMData) throws {
        throw UTMDataError.notImplemented
    }

    override func create<Config: UTMConfiguration>(config: Config) async throws -> VMData {
        throw UTMDataError.notImplemented
    }

    @discardableResult
    override func delete(vm: VMData, alsoRegistry: Bool) async throws -> Int? {
        throw UTMDataError.notImplemented
    }

    @discardableResult
    override func clone(vm: VMData) async throws -> VMData {
        throw UTMDataError.notImplemented
    }

    override func export(vm: VMData, to url: URL) async throws {
        throw UTMDataError.notImplemented
    }

    override func move(vm: VMData, to url: URL) async throws {
        throw UTMDataError.notImplemented
    }

    override func template(vm: VMData) async throws {
        throw UTMDataError.notImplemented
    }

    override func computeSize(for vm: VMData) async -> Int64 {
        (try? await remoteClient.server.getPackageSize(for: vm.id)) ?? 0
    }

    override func importUTM(from url: URL, asShortcut: Bool) async throws {
        throw UTMDataError.notImplemented
    }

    override func mountSupportTools(for vm: any UTMVirtualMachine) async throws {
        try await remoteClient.server.mountGuestToolsOnVirtualMachine(id: vm.id)
    }
}
#endif
