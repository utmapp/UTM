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
#endif
#if canImport(AltKit)
import AltKit
#endif

@available(iOS 14, macOS 11, *)
struct AlertMessage: Identifiable {
    var message: String
    public var id: String {
        message
    }
    
    init(_ message: String) {
        self.message = message
    }
}

@available(iOS 14, macOS 11, *)
class UTMData: ObservableObject {
    
    /// Sandbox location for storing .utm bundles
    static var defaultStorageUrl: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// View: show VM settings
    @MainActor @Published var showSettingsModal: Bool
    
    /// View: show new VM wizard
    @MainActor @Published var showNewVMSheet: Bool
    
    /// View: show an alert message
    @MainActor @Published var alertMessage: AlertMessage?
    
    /// View: show busy spinner
    @MainActor @Published var busy: Bool
    
    /// View: currently selected VM
    @MainActor @Published var selectedVM: UTMVirtualMachine?
    
    /// View: all VMs listed, we save a bookmark to each when array is modified
    @MainActor @Published private(set) var virtualMachines: [UTMVirtualMachine] {
        didSet {
            listSaveToDefaults()
        }
    }
    
    /// View: all pending VMs listed (ZIP and IPSW downloads)
    @MainActor @Published private(set) var pendingVMs: [UTMPendingVirtualMachine]
    
    /// Temporary storage for QEMU removable drives settings
    private var qemuRemovableDrivesCache: [String: URL]
    
    #if os(macOS)
    /// View controller for every VM currently active
    var vmWindows: [UTMVirtualMachine: VMDisplayWindowController] = [:]
    #else
    /// View controller for currently active VM
    var vmVC: VMDisplayViewController?
    #endif
    
    /// Shortcut for accessing FileManager.default
    private var fileManager: FileManager {
        FileManager.default
    }
    
    /// Shortcut for accessing storage URL from instance
    private var documentsURL: URL {
        UTMData.defaultStorageUrl
    }
    
    /// Queue to run `busyWork` tasks
    private var busyQueue: DispatchQueue
    
    @MainActor
    init() {
        self.busyQueue = DispatchQueue(label: "UTM Busy Queue", qos: .userInitiated)
        self.showSettingsModal = false
        self.showNewVMSheet = false
        self.busy = false
        self.virtualMachines = []
        self.qemuRemovableDrivesCache = [:]
        self.pendingVMs = []
        self.selectedVM = nil
        listLoadFromDefaults()
    }
    
    // MARK: - VM listing
    
    /// Re-loads UTM bundles from default path
    ///
    /// This removes stale entries (deleted/not accessible) and duplicate entries
    func listRefresh() async {
        // remove stale vm
        var list = await virtualMachines.filter { (vm: UTMVirtualMachine) in vm.path != nil && fileManager.fileExists(atPath: vm.path!.path) }
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            let newFiles = files.filter { newFile in
                !list.contains { existingVM in
                    existingVM.path?.standardizedFileURL == newFile.standardizedFileURL
                }
            }
            for file in newFiles {
                guard try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false else {
                    continue
                }
                guard UTMVirtualMachine.isVirtualMachine(url: file) else {
                    continue
                }
                let vm = UTMVirtualMachine(url: file)
                if vm != nil {
                    list.insert(vm!, at: 0)
                } else {
                    logger.error("Failed to create object for \(file)")
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        if await virtualMachines != list {
            await listReplace(with: list)
        }
    }
    
    /// Load VM list (and order) from persistent storage
    @MainActor private func listLoadFromDefaults() {
        let defaults = UserDefaults.standard
        // legacy path list
        if let files = defaults.array(forKey: "VMList") as? [String] {
            virtualMachines = files.uniqued().compactMap({ file in
                let url = documentsURL.appendingPathComponent(file, isDirectory: true)
                return UTMVirtualMachine(url: url)
            })
        }
        // bookmark list
        if let bookmarks = defaults.array(forKey: "VMList") as? [Data] {
            let documentsURL = self.documentsURL.standardizedFileURL
            virtualMachines = bookmarks.compactMap { bookmark in
                let vm = UTMVirtualMachine(bookmark: bookmark)
                let parentUrl = vm?.path!.deletingLastPathComponent().standardizedFileURL
                if parentUrl != documentsURL {
                    vm?.isShortcut = true
                }
                return vm
            }
        }
    }
    
    /// Save VM list (and order) to persistent storage
    @MainActor private func listSaveToDefaults() {
        let defaults = UserDefaults.standard
        let bookmarks = virtualMachines.compactMap { vm -> Data? in
            #if os(macOS)
            if let appleVM = vm as? UTMAppleVirtualMachine {
                if appleVM.isShortcut {
                    return nil // FIXME: Apple VMs do not support shortcuts
                }
            }
            #endif
            return vm.bookmark
        }
        defaults.set(bookmarks, forKey: "VMList")
    }
    
    @MainActor private func listReplace(with vms: [UTMVirtualMachine]) {
        virtualMachines = vms
    }
    
    /// Add VM to list
    /// - Parameter vm: VM to add
    @MainActor private func listAdd(vm: UTMVirtualMachine) {
        virtualMachines.append(vm)
        listSelect(vm: vm)
    }
    
    /// Select VM in list
    /// - Parameter vm: VM to select
    @MainActor public func listSelect(vm: UTMVirtualMachine) {
        selectedVM = vm
    }
    
    /// Remove a VM from list
    /// - Parameter vm: VM to remove
    @MainActor public func listRemove(vm: UTMVirtualMachine) {
        if let index = virtualMachines.firstIndex(of: vm) {
            virtualMachines.remove(at: index)
        }
        if vm == selectedVM {
            selectedVM = nil
        }
        vm.viewState.deleted = true // alert views to update
    }
    
    /// Add pending VM to list
    /// - Parameter pendingVM: Pending VM to add
    @MainActor private func listAdd(pendingVM: UTMPendingVirtualMachine) {
        pendingVMs.append(pendingVM)
    }
    
    /// Remove pending VM from list
    /// - Parameter pendingVM: Pending VM to remove
    @MainActor private func listRemove(pendingVM: UTMPendingVirtualMachine) {
        pendingVMs.removeAll(where: { $0.id == pendingVM.id })
    }
    
    /// Move items in VM list
    /// - Parameters:
    ///   - fromOffsets: Offsets from move from
    ///   - toOffset: Offsets to move to
    @MainActor func listMove(fromOffsets: IndexSet, toOffset: Int) {
        virtualMachines.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    /// Discard and create a new list item
    /// - Parameter vm: VM to discard
    /// - Parameter newVM: VM to replace with
    @MainActor private func listRecreate(vm: UTMVirtualMachine, with newVM: UTMVirtualMachine) {
        if let index = virtualMachines.firstIndex(of: vm) {
            virtualMachines.remove(at: index)
            virtualMachines.insert(newVM, at: index)
        } else {
            virtualMachines.insert(newVM, at: 0)
        }
        if selectedVM == vm {
            selectedVM = newVM
        }
    }
    
    // MARK: - New name
    
    /// Generate a unique VM name
    /// - Parameter base: Base name
    /// - Returns: Unique name for a non-existing item in the default storage path
    func newDefaultVMName(base: String = "Virtual Machine") -> String {
        let nameForId = { (i: Int) in i <= 1 ? base : "\(base) \(i)" }
        for i in 1..<1000 {
            let name = nameForId(i)
            let file = UTMVirtualMachine.virtualMachinePath(name, inParentURL: documentsURL)
            if !fileManager.fileExists(atPath: file.path) {
                return name
            }
        }
        return ProcessInfo.processInfo.globallyUniqueString
    }
    
    /// Generate a unique QCOW2 drive name for QEMU
    /// - Parameters:
    ///   - type: Image type
    ///   - forConfig: UTM QEMU configuration that will hold this drive
    /// - Returns: Unique name for a non-existing item in the .utm data path
    private func newDefaultDrivePath(type: UTMDiskImageType, forConfig: UTMQemuConfiguration) -> String {
        let nameForId = { (i: Int) in "\(type.description)-\(i).qcow2" }
        for i in 0..<1000 {
            let name = nameForId(i)
            let file = forConfig.imagesPath.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: file.path) {
                return name
            }
        }
        return UUID().uuidString
    }
    
    /// Generate a default drive name for QEMU
    /// - Parameter config: UTM QEMU configuration that will use the drive
    /// - Returns: Unique name for the new drive
    private func newDefaultDriveName(for config: UTMQemuConfiguration) -> String {
        let nameForId = { (i: Int) in "drive\(i)" }
        for i in 0..<1000 {
            let name = nameForId(i)
            var free: Bool = true
            for j in 0..<config.countDrives {
                guard let taken = config.driveName(for: j) else {
                    continue
                }
                if taken == name {
                    free = false
                    break
                }
            }
            if free {
                return name
            }
        }
        return UUID().uuidString
    }
    
    // MARK: - Other view states
    
    @MainActor private func setBusyIndicator(_ busy: Bool) {
        self.busy = busy
    }
    
    @MainActor private func showErrorAlert(message: String) {
        alertMessage = AlertMessage(message)
    }
    
    @MainActor func newVM() {
        showSettingsModal = false
        showNewVMSheet = true
    }
    
    @MainActor func showSettingsForCurrentVM() {
        showSettingsModal = true
    }
    
    // MARK: - VM operations
    
    /// Save an existing VM to disk
    /// - Parameter vm: VM to save
    func save(vm: UTMVirtualMachine) async throws {
        do {
            try vm.saveUTM()
            if let qemuVM = vm as? UTMQemuVirtualMachine {
                try commitRemovableDriveImages(for: qemuVM)
            }
        } catch {
            // refresh the VM object as it is now stale
            do {
                try discardChanges(for: vm)
            } catch {
                // if we can't discard changes, recreate the VM from scratch
                guard let path = vm.path else {
                    logger.error("Attempting to refresh unsaved VM \(vm.title)")
                    return
                }
                guard let newVM = UTMVirtualMachine(url: path) else {
                    logger.debug("Cannot create new object for \(path.path)")
                    return
                }
                await listRecreate(vm: vm, with: newVM)
            }
            throw error
        }
    }
    
    /// Discard changes to VM configuration
    /// - Parameter vm: VM configuration to discard
    func discardChanges(for vm: UTMVirtualMachine? = nil) throws {
        let config: UTMQemuConfiguration
        if let vm = vm, vm.path != nil {
            try vm.reloadConfiguration()
            guard let qemuConfig = vm.config as? UTMQemuConfiguration else {
                // FIXME: non-qemu orphaned drives
                return
            }
            config = qemuConfig
        } else {
            // create a tmp empty config so we can get orphanedDrives for tmp path
            config = UTMQemuConfiguration()
        }
        // delete orphaned drives
        guard let orphanedDrives = config.orphanedDrives else {
            return
        }
        for name in orphanedDrives {
            let imagesPath = config.imagesPath
            let orphanPath = imagesPath.appendingPathComponent(name)
            logger.debug("Removing orphaned drive '\(name)'")
            try fileManager.removeItem(at: orphanPath)
        }
    }
    
    /// Save a new VM to disk
    /// - Parameters:
    ///   - config: New VM configuration
    func create(config: UTMConfigurable) async throws -> UTMVirtualMachine {
        guard await !virtualMachines.contains(where: { $0.config.name == config.name }) else {
            throw NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
        }
        let vm = UTMVirtualMachine(configuration: config, withDestinationURL: documentsURL)
        try await save(vm: vm)
        if let qemuVM = vm as? UTMQemuVirtualMachine {
            try commitRemovableDriveImages(for: qemuVM)
        }
        await listAdd(vm: vm)
        return vm
    }
    
    /// Delete a VM from disk
    /// - Parameter vm: VM to delete
    func delete(vm: UTMVirtualMachine) async throws {
        try fileManager.removeItem(at: vm.path!)
        
        await listRemove(vm: vm)
    }
    
    /// Save a copy of the VM and all data to default storage location
    /// - Parameter vm: VM to clone
    func clone(vm: UTMVirtualMachine) async throws {
        let newName: String = newDefaultVMName(base: vm.title)
        let newPath = UTMVirtualMachine.virtualMachinePath(newName, inParentURL: documentsURL)
        
        try fileManager.copyItem(at: vm.path!, to: newPath)
        guard let newVM = UTMVirtualMachine(url: newPath) else {
            throw NSLocalizedString("Failed to clone VM.", comment: "UTMData")
        }
        await listAdd(vm: newVM)
    }
    
    /// Save a copy of the VM and all data to arbitary location
    /// - Parameters:
    ///   - vm: VM to copy
    ///   - url: Location to copy to (must be writable)
    func export(vm: UTMVirtualMachine, to url: URL) throws {
        let sourceUrl = vm.path!
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.copyItem(at: sourceUrl, to: url)
    }
    
    /// Save a copy of the VM and all data to arbitary location and delete the original data
    /// - Parameters:
    ///   - vm: VM to move
    ///   - url: Location to move to (must be writable)
    func move(vm: UTMVirtualMachine, to url: URL) async throws {
        try export(vm: vm, to: url)
        guard let newVM = UTMVirtualMachine(url: url) else {
            throw NSLocalizedString("Unable to add a shortcut to the new location.", comment: "UTMData")
        }
        newVM.isShortcut = true
        try await newVM.accessShortcut()
        
        try await delete(vm: vm)
        await listAdd(vm: newVM)
        #if os(macOS)
        if let _ = newVM as? UTMAppleVirtualMachine {
            throw NSLocalizedString("Shortcuts to Apple virtual machines cannot be stored. You must open the .utm bundle from Finder each time UTM is launched.", comment: "UTMData")
        }
        #endif
    }
    
    /// Open settings modal
    /// - Parameter vm: VM to edit settings
    @MainActor func edit(vm: UTMVirtualMachine) {
        // show orphans for proper removal
        if let config = vm.config as? UTMQemuConfiguration {
            config.recoverOrphanedDrives()
        }
        selectedVM = vm
        showNewVMSheet = false
        // SwiftUI bug: cannot show modal at the same time as changing selected VM or it breaks
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
            self.showSettingsModal = true
        }
    }
    
    // MARK: - File I/O related
    
    /// Calculate total size of VM and data
    /// - Parameter vm: VM to calculate size
    /// - Returns: Size in bytes
    func computeSize(for vm: UTMVirtualMachine) -> Int64 {
        guard let path = vm.path else {
            logger.error("invalid path for vm")
            return 0
        }
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.totalFileSizeKey]) else {
            logger.error("failed to create enumerator for \(path)")
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileSizeKey]), let size = resourceValues.totalFileSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }
    
    /// Handles UTM file URLs
    ///
    /// If .utm is already in the list, select it
    /// If .utm is in the Inbox directory, move it to the default storage
    /// Otherwise we create a shortcut (default for macOS) or a copy (default for iOS)
    /// - Parameter url: File URL to read from
    /// - Parameter asShortcut: Create a shortcut rather than a copy
    func importUTM(from url: URL, asShortcut: Bool) async throws {
        guard url.isFileURL else { return }
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        logger.info("importing: \(url)")
        let fileBasePath = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let dest = documentsURL.appendingPathComponent(fileName, isDirectory: true)
        if let vm = await virtualMachines.first(where: { vm -> Bool in
            guard let vmPath = vm.path else {
                return false
            }
            return vmPath.standardizedFileURL == url.standardizedFileURL
        }) {
            logger.info("found existing vm!")
            await listSelect(vm: vm)
            return
        }
        // check if VM is valid
        guard let _ = UTMVirtualMachine(url: url) else {
            throw NSLocalizedString("Cannot import this VM. Either the configuration is invalid, created in a newer version of UTM, or on a platform that is incompatible with this version of UTM.", comment: "UTMData")
        }
        let vm: UTMVirtualMachine?
        if (fileBasePath.resolvingSymlinksInPath().path == documentsURL.appendingPathComponent("Inbox", isDirectory: true).path) {
            logger.info("moving from Inbox")
            try fileManager.moveItem(at: url, to: dest)
            vm = UTMVirtualMachine(url: dest)
        } else if asShortcut {
            logger.info("loading as a shortcut")
            vm = UTMVirtualMachine(url: url)
            vm?.isShortcut = true
            try await vm?.accessShortcut()
        } else {
            logger.info("copying to Documents")
            try fileManager.copyItem(at: url, to: dest)
            vm = UTMVirtualMachine(url: dest)
        }
        guard let vm = vm else {
            throw NSLocalizedString("Failed to parse imported VM.", comment: "UTMData")
        }
        await listAdd(vm: vm)
    }
    
    #if os(macOS)
    func importUTM(from url: URL) async throws {
        try await importUTM(from: url, asShortcut: true)
    }
    #else
    func importUTM(from url: URL) async throws {
        try await importUTM(from: url, asShortcut: false)
    }
    #endif
    
    // MARK: - Downloading VMs
    
    #if os(macOS) && arch(arm64)
    /// Create a new VM using configuration and downloaded IPSW
    /// - Parameter config: Apple VM configuration
    @available(macOS 12, *)
    func downloadIPSW(using config: UTMAppleConfiguration) {
        Task {
            let task = UTMDownloadIPSWTask(for: config)
            do {
                guard await !virtualMachines.contains(where: { $0.config.name == config.name }) else {
                    throw NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
                }
                await listAdd(pendingVM: task.pendingVM)
                if let vm = try await task.download() {
                    try await save(vm: vm)
                    await listAdd(vm: vm)
                }
            } catch {
                await showErrorAlert(message: error.localizedDescription)
            }
            await listRemove(pendingVM: task.pendingVM)
        }
    }
    #endif
    
    /// Create a new VM by downloading a .zip and extracting it
    /// - Parameter components: Download URL components
    func downloadUTMZip(from components: URLComponents) {
        guard let urlParameter = components.queryItems?.first(where: { $0.name == "url" })?.value,
           urlParameter.contains(".zip"), let url = URL(string: urlParameter) else {
               return
        }
        Task {
            let task = UTMDownloadVMTask(for: url)
            do {
                await listAdd(pendingVM: task.pendingVM)
                if let vm = try await task.download() {
                    await listAdd(vm: vm)
                }
            } catch {
                await showErrorAlert(message: error.localizedDescription)
            }
            await listRemove(pendingVM: task.pendingVM)
        }
    }
    
    /// Cancel a download and discard any data
    /// - Parameter pendingVM: Pending VM to cancel
    func cancelDownload(for pendingVM: UTMPendingVirtualMachine) {
        pendingVM.cancel()
    }
    
    // MARK: - QEMU Disk drive I/O handling
    
    /// Import an existing drive image
    /// - Parameters:
    ///   - drive: File URL to drive
    ///   - config: QEMU configuration to add to
    ///   - imageType: Disk image type
    ///   - interface: Interface to add to
    ///   - copy: Make a copy of the file (if false, file will be moved)
    func importDrive(_ drive: URL, for config: UTMQemuConfiguration, imageType: UTMDiskImageType, on interface: String, copy: Bool) throws {
        _ = drive.startAccessingSecurityScopedResource()
        defer { drive.stopAccessingSecurityScopedResource() }
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: drive.path, isDirectory: &isDir), !isDir.boolValue else {
            if drive.pathExtension == "utm" {
                throw NSLocalizedString("You cannot import a .utm package as a drive. Did you mean to open the package with UTM?", comment: "UTMData")
            } else {
                throw NSLocalizedString("You cannot import a directory as a drive.", comment: "UTMData")
            }
        }
        
        var path = drive.lastPathComponent
        let imagesPath = config.imagesPath
        var dstPath = imagesPath.appendingPathComponent(path)
        if !fileManager.fileExists(atPath: imagesPath.path) {
            try fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: false, attributes: nil)
        }
        if copy {
            #if os(macOS)
            if UTMQemuConfiguration.shouldConvertQcow2(forInterface: interface) {
                dstPath.deletePathExtension()
                dstPath.appendPathExtension("qcow2")
                path = dstPath.lastPathComponent
                try UTMQemuImage.convert(from: drive, toQcow2: dstPath)
            } else {
                try fileManager.copyItem(at: drive, to: dstPath)
            }
            #else
            try fileManager.copyItem(at: drive, to: dstPath)
            #endif
        } else {
            try fileManager.moveItem(at: drive, to: dstPath)
        }
        DispatchQueue.main.async {
            let name = self.newDefaultDriveName(for: config)
            config.newDrive(name, path: path, type: imageType, interface: interface)
        }
    }
    
    func importDrive(_ drive: URL, for config: UTMQemuConfiguration, copy: Bool = true) throws {
        let imageType: UTMDiskImageType = drive.pathExtension.lowercased() == "iso" ? .CD : .disk
        let interface: String
        if let target = config.systemTarget, let arch = config.systemArchitecture {
            interface = UTMQemuConfiguration.defaultDriveInterface(forTarget: target, architecture: arch, type: imageType)
        } else {
            interface = "none"
        }
        try importDrive(drive, for: config, imageType: imageType, on: interface, copy: copy)
    }
    
    /// Create a new QCOW2 disk image
    /// - Parameters:
    ///   - drive: Create parameters
    ///   - config: QEMU configuration to add to
    ///   - driveImage: Disk image type
    func createDrive(_ drive: VMDriveImage, for config: UTMQemuConfiguration, with driveImage: URL? = nil) throws {
        var path: String = ""
        if !drive.removable {
            assert(driveImage == nil, "Cannot call createDrive with a driveImage!")
            guard drive.size > 0 else {
                throw NSLocalizedString("Invalid drive size.", comment: "UTMData")
            }
            path = newDefaultDrivePath(type: drive.imageType, forConfig: config)
            let imagesPath = config.imagesPath
            let dstPath = imagesPath.appendingPathComponent(path)
            if !fileManager.fileExists(atPath: imagesPath.path) {
                try fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: false, attributes: nil)
            }
            
            // create drive
            if !GenerateDefaultQcow2File(dstPath as CFURL, drive.size) {
                throw NSLocalizedString("Disk creation failed.", comment: "UTMData")
            }
        }
        
        let name = self.newDefaultDriveName(for: config)
        if let url = driveImage {
            qemuRemovableDrivesCache[name] = url
        }
        DispatchQueue.main.async {
            let interface = drive.interface ?? "none"
            if drive.removable {
                config.newRemovableDrive(name, type: drive.imageType, interface: interface)
            } else {
                config.newDrive(name, path: path, type: drive.imageType, interface: interface)
            }
        }
    }
    
    /// Delete a drive image data and settings from a QEMU configuration
    /// - Parameters:
    ///   - index: Index of drive in configuration
    ///   - config: QEMU configuration
    func removeDrive(at index: Int, for config: UTMQemuConfiguration) throws {
        if let path = config.driveImagePath(for: index) {
            let fullPath = config.imagesPath.appendingPathComponent(path);
            if fileManager.fileExists(atPath: fullPath.path) {
                try fileManager.removeItem(at: fullPath)
            }
        }
        if let name = config.driveName(for: index) {
            qemuRemovableDrivesCache.removeValue(forKey: name)
        }
        DispatchQueue.main.async {
            config.removeDrive(at: index)
        }
    }
    
    /// Perform removable drive changes for cached items
    ///
    /// We do not store removable drive bookmarks in config.plist so we cache the removable drives until the VM is saved.
    /// - Parameter vm: QEMU VM that will take the cached images
    private func commitRemovableDriveImages(for vm: UTMQemuVirtualMachine) throws {
        let drives = vm.drives
        defer {
            qemuRemovableDrivesCache.removeAll()
        }
        try qemuRemovableDrivesCache.forEach { name, url in
            let drive = drives.first { drive in
                drive.name == name
            }
            if let drive = drive {
                try vm.changeMedium(for: drive, url: url)
            }
        }
    }
    
    // MARK: - Other utility functions
    
    /// In some regions, iOS will prompt the user for network access
    func triggeriOSNetworkAccessPrompt() {
        let task = URLSession.shared.dataTask(with: URL(string: "http://captive.apple.com")!)
        task.resume()
    }
    
    /// Check if a QEMU target is supported
    /// - Parameter systemArchitecture: QEMU architecture
    /// - Returns: true if UTM is compiled with the supporting binaries
    func isSupported(systemArchitecture: String?) -> Bool {
        guard let arch = systemArchitecture else {
            return true // ignore this
        }
        let bundleURL = Bundle.main.bundleURL
        #if os(macOS)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let base = "Versions/A/"
        #else
        let contentsURL = bundleURL
        let base = ""
        #endif
        let frameworksURL = contentsURL.appendingPathComponent("Frameworks", isDirectory: true)
        let framework = frameworksURL.appendingPathComponent("qemu-" + arch + "-softmmu.framework/" + base + "qemu-" + arch + "-softmmu", isDirectory: false)
        logger.error("\(framework.path)")
        return fileManager.fileExists(atPath: framework.path)
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
    func automationSendText(to vm: UTMVirtualMachine, urlComponents components: URLComponents) {
        guard let qemuVm = vm as? UTMQemuVirtualMachine else { return } // FIXME: implement for Apple VM
        guard let queryItems = components.queryItems else { return }
        guard let text = queryItems.first(where: { $0.name == "text" })?.value else { return }
        if qemuVm.qemuConfig.displayConsoleOnly {
            qemuVm.sendInput(text)
        } else {
            #if os(macOS)
            trySendTextSpice(vm: qemuVm, text: text)
            #else
            trySendTextSpice(text)
            #endif
        }
    }
    
    /// Send mouse/tablet coordinates to VM
    /// - Parameters:
    ///   - vm: VM to send mouse/tablet coordinates to
    ///   - components: Data (see UTM Wiki for details)
    func automationSendMouse(to vm: UTMVirtualMachine, urlComponents components: URLComponents) {
        guard let qemuVm = vm as? UTMQemuVirtualMachine else { return } // FIXME: implement for Apple VM
        guard !qemuVm.qemuConfig.displayConsoleOnly else { return }
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
        tryClickAtPoint(vm: qemuVm, point: point, button: button)
        #else
        tryClickAtPoint(point: point, button: button)
        #endif
    }

    // MARK: - AltKit
    
#if canImport(AltKit)
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
            throw NSLocalizedString("Cannot find AltServer for JIT enable. You cannot run VMs until JIT is enabled.", comment: "UTMData")
        } else if let error = connectError {
            throw NSLocalizedString("AltJIT error: \(error.localizedDescription)", comment: "UTMData")
        }
    }
#endif
}
