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

struct AlertMessage: Identifiable {
    var message: String
    public var id: String {
        message
    }
    
    init(_ message: String) {
        self.message = message
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
    @Published var alertMessage: AlertMessage?
    
    /// View: show busy spinner
    @Published var busy: Bool
    
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
                guard UTMQemuVirtualMachine.isVirtualMachine(url: file) else {
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
    private func listLoadFromDefaults() {
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
        virtualMachines = list.uniqued().compactMap { uuidString in
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
    }
    
    /// Load VM list (and order) from persistent storage (legacy)
    private func listLegacyLoadFromDefaults() {
        let defaults = UserDefaults.standard
        // legacy path list
        if let files = defaults.array(forKey: "VMList") as? [String] {
            virtualMachines = files.uniqued().compactMap({ file in
                let url = documentsURL.appendingPathComponent(file, isDirectory: true)
                if let vm = try? VMData(url: url) {
                    return vm
                } else {
                    return nil
                }
            })
        }
        // bookmark list
        if let list = defaults.array(forKey: "VMList") {
            virtualMachines = list.compactMap { item in
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
        }
    }
    
    /// Save VM list (and order) to persistent storage
    private func listSaveToDefaults() {
        let defaults = UserDefaults.standard
        let wrappedVMs = virtualMachines.map { $0.id.uuidString }
        defaults.set(wrappedVMs, forKey: "VMEntryList")
    }
    
    private func listReplace(with vms: [VMData]) {
        virtualMachines = vms
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
            let file = UTMQemuVirtualMachine.virtualMachinePath(for: name, in: documentsURL)
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
        alertMessage = AlertMessage(message)
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
        try await save(vm: vm)
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
        let newPath = UTMQemuVirtualMachine.virtualMachinePath(for: newName, in: documentsURL)
        
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
    func computeSize(for vm: VMData) -> Int64 {
        let path = vm.pathUrl
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else {
            logger.error("failed to create enumerator for \(path)")
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
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
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

    func copyItemWithCopyfile(at srcURL: URL, to dstURL: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let status = copyfile(srcURL.path, dstURL.path, nil, copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE | COPYFILE_DATA_SPARSE))
            if status < 0 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }.value
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
    func downloadUTMZip(from components: URLComponents) async {
        guard let urlParameter = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let url = URL(string: urlParameter) else {
               showErrorAlert(message: NSLocalizedString("Failed to parse download URL.", comment: "UTMData"))
               return
        }
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
    
    func mountSupportTools(for vm: UTMQemuVirtualMachine) async throws {
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
        try await UTMQemuImage.convert(from: driveUrl, toQcow2: dstUrl, withCompression: isCompressed)
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
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    
    /// Execute a task with spinning progress indicator (Swift concurrency version)
    /// - Parameter work: Function to execute
    func busyWorkAsync(_ work: @escaping @Sendable () async throws -> Void) {
        Task.detached(priority: .userInitiated) {
            await self.setBusyIndicator(true)
            do {
                try await work()
            } catch {
                logger.error("\(error)")
                await self.showErrorAlert(message: error.localizedDescription)
            }
            await self.setBusyIndicator(false)
        }
    }
    
    // MARK: - Automation Features
    
    /// Send text as keyboard input to VM
    /// - Parameters:
    ///   - vm: VM to send text to
    ///   - components: Data (see UTM Wiki for details)
    func automationSendText(to vm: VMData, urlComponents components: URLComponents) {
        guard let queryItems = components.queryItems else { return }
        guard let text = queryItems.first(where: { $0.name == "text" })?.value else { return }
        #if os(macOS)
        trySendTextSpice(vm: vm, text: text)
        #else
        trySendTextSpice(text)
        #endif
    }
    
    /// Send mouse/tablet coordinates to VM
    /// - Parameters:
    ///   - vm: VM to send mouse/tablet coordinates to
    ///   - components: Data (see UTM Wiki for details)
    func automationSendMouse(to vm: VMData, urlComponents components: URLComponents) {
        guard let qemuVm = vm.wrapped as? UTMQemuVirtualMachine else { return } // FIXME: implement for Apple VM
        guard !qemuVm.config.displays.isEmpty else { return }
        guard let queryItems = components.queryItems else { return }
        /// Parse targeted position
        var x: CGFloat? = nil
        var y: CGFloat? = nil
        let nf = NumberFormatter()
        nf.allowsFloats = false
        if let xStr = components.queryItems?.first(where: { item in
            item.name == "x"
        })?.value {
            x = nf.number(from: xStr) as? CGFloat
        }
        if let yStr = components.queryItems?.first(where: { item in
            item.name == "y"
        })?.value {
            y = nf.number(from: yStr) as? CGFloat
        }
        guard let xPos = x, let yPos = y else { return }
        let point = CGPoint(x: xPos, y: yPos)
        /// Parse which button should be clicked
        var button: CSInputButton = .left
        if let buttonStr = queryItems.first(where: { $0.name == "button"})?.value {
            switch buttonStr {
            case "middle":
                button = .middle
                break
            case "right":
                button = .right
                break
            default:
                break
            }
        }
        /// All parameters parsed, perform the click
        #if os(macOS)
        tryClickAtPoint(vm: vm, point: point, button: button)
        #else
        tryClickAtPoint(point: point, button: button)
        #endif
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
    case cloneFailed
    case shortcutCreationFailed
    case importFailed
    case importParseFailed
    case altServerNotFound
    case altJitError(String)
    case jitStreamerDecodeFailed
    case jitStreamerAttachFailed
    case jitStreamerUrlInvalid(String)
}

extension UTMDataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .virtualMachineAlreadyExists:
            return NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
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
        }
    }
}
