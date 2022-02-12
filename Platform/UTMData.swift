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
    
    static var defaultStorageUrl: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    @Published var showSettingsModal: Bool
    @Published var showNewVMSheet: Bool
    @Published var alertMessage: AlertMessage?
    @MainActor @Published var busy: Bool
    @MainActor @Published var selectedVM: UTMVirtualMachine?
    @Published private(set) var virtualMachines: [UTMVirtualMachine] {
        didSet {
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
    }
    @Published private(set) var pendingVMs: [UTMPendingVirtualMachine]
    
    private var selectedDiskImagesCache: [String: URL]
    
    #if os(macOS)
    var vmWindows: [UTMVirtualMachine: VMDisplayWindowController] = [:]
    #else
    var vmVC: VMDisplayViewController?
    #endif
    
    var fileManager: FileManager {
        FileManager.default
    }
    
    var documentsURL: URL {
        UTMData.defaultStorageUrl
    }
    
    private var busyQueue: DispatchQueue
    
    @MainActor
    init() {
        let defaults = UserDefaults.standard
        self.busyQueue = DispatchQueue(label: "UTM Busy Queue", qos: .userInitiated)
        self.showSettingsModal = false
        self.showNewVMSheet = false
        self.busy = false
        self.virtualMachines = []
        self.selectedDiskImagesCache = [:]
        self.pendingVMs = []
        var virtualMachines = [UTMVirtualMachine]()
        // legacy path list
        if let files = defaults.array(forKey: "VMList") as? [String] {
            for file in files.uniqued() {
                let url = documentsURL.appendingPathComponent(file, isDirectory: true)
                if let vm = UTMVirtualMachine(url: url) {
                    virtualMachines.append(vm)
                }
            }
        }
        // bookmark list
        if let bookmarks = defaults.array(forKey: "VMList") as? [Data] {
            let documentsURL = self.documentsURL.standardizedFileURL
            for bookmark in bookmarks {
                if let vm = UTMVirtualMachine(bookmark: bookmark) {
                    let parentUrl = vm.path!.deletingLastPathComponent().standardizedFileURL
                    if parentUrl != documentsURL {
                        vm.isShortcut = true
                    }
                    if !virtualMachines.contains(where: { $0.path!.standardizedFileURL == vm.path!.standardizedFileURL }) {
                        virtualMachines.append(vm)
                    }
                }
            }
        }
        self.virtualMachines = virtualMachines
        self.selectedVM = nil
    }
    
    func refresh() {
        // remove stale vm
        var list = virtualMachines.filter { (vm: UTMVirtualMachine) in vm.path != nil && fileManager.fileExists(atPath: vm.path!.path) }
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            let newFiles = files.filter { newFile in
                !virtualMachines.contains { existingVM in
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
        if virtualMachines != list {
            DispatchQueue.main.async {
                //self.objectWillChange.send()
                self.virtualMachines = list
            }
        }
    }
    
    // MARK: - New name
    
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
    
    func newDefaultDrivePath(type: UTMDiskImageType, forConfig: UTMQemuConfiguration) -> String {
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
    
    func newDefaultDriveName(for config: UTMQemuConfiguration) -> String {
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
    
    // MARK: - VM functions
    
    func save(vm: UTMVirtualMachine) throws {
        do {
            let oldPath = vm.path
            try vm.saveUTM()
            if let qemuVM = vm as? UTMQemuVirtualMachine {
                try commitDiskImages(for: qemuVM)
            }
            let newPath = vm.path
            // change the saved path
            if oldPath?.path != newPath?.path {
                guard let oldName = oldPath?.lastPathComponent else {
                    return
                }
                guard let newName = newPath?.lastPathComponent else {
                    return
                }
                let defaults = UserDefaults.standard
                if var files = defaults.array(forKey: "VMList") as? [String] {
                    if let index = files.firstIndex(of: oldName) {
                        files[index] = newName
                        defaults.set(files, forKey: "VMList")
                    }
                }
            }
        } catch {
            // refresh the VM object as it is now stale
            do {
                try discardChanges(forVM: vm)
            } catch {
                // if we can't discard changes, recreate the VM from scratch
                recreate(vm: vm)
            }
            throw error
        }
    }
    
    func discardChanges(forVM vm: UTMVirtualMachine? = nil) throws {
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
    
    func create(config: UTMConfigurable, onCompletion: @escaping (UTMVirtualMachine) -> Void = { _ in }) throws {
        guard !virtualMachines.contains(where: { $0.config.name == config.name }) else {
            throw NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
        }
        let vm = UTMVirtualMachine(configuration: config, withDestinationURL: documentsURL)
        try save(vm: vm)
        if let qemuVM = vm as? UTMQemuVirtualMachine {
            try commitDiskImages(for: qemuVM)
        }
        DispatchQueue.main.async {
            self.virtualMachines.append(vm)
            onCompletion(vm)
        }
    }
    
    // MARK: - View state modifiers
    
    @MainActor private func addNew(vm: UTMVirtualMachine) {
        virtualMachines.append(vm)
        select(vm: vm)
    }
    
    @MainActor public func select(vm: UTMVirtualMachine) {
        selectedVM = vm
    }
    
    @MainActor public func remove(vm: UTMVirtualMachine) {
        if let index = virtualMachines.firstIndex(of: vm) {
            virtualMachines.remove(at: index)
        }
        if vm == selectedVM {
            selectedVM = nil
        }
        vm.viewState.deleted = true // alert views to update
    }
    
    @MainActor private func addNew(pendingVM: UTMPendingVirtualMachine) {
        pendingVMs.append(pendingVM)
    }
    
    @MainActor private func remove(pendingVM: UTMPendingVirtualMachine) {
        pendingVMs.removeAll(where: { $0.id == pendingVM.id })
    }
    
    public func cancelPendingVM(_ pendingVM: UTMPendingVirtualMachine) {
        pendingVM.cancel()
    }
    
    @MainActor private func setBusyIndicator(_ busy: Bool) {
        self.busy = busy
    }
    
    @MainActor private func showErrorAlert(message: String) {
        alertMessage = AlertMessage(message)
    }
    
    // MARK: - File operations
    
    #if os(macOS) && arch(arm64)
    @available(macOS 12, *)
    func createPendingIPSWDownload(config: UTMAppleConfiguration) {
        Task {
            let task = UTMDownloadIPSWTask(for: config)
            do {
                guard !virtualMachines.contains(where: { $0.config.name == config.name }) else {
                    throw NSLocalizedString("An existing virtual machine already exists with this name.", comment: "UTMData")
                }
                await addNew(pendingVM: task.pendingVM)
                if let vm = try await task.download() {
                    try save(vm: vm)
                    await addNew(vm: vm)
                }
            } catch {
                await showErrorAlert(message: error.localizedDescription)
            }
            await remove(pendingVM: task.pendingVM)
        }
    }
    #endif
    
    func move(fromOffsets: IndexSet, toOffset: Int) {
        DispatchQueue.main.async {
            self.virtualMachines.move(fromOffsets: fromOffsets, toOffset: toOffset)
        }
    }
    
    func delete(vm: UTMVirtualMachine) throws {
        try fileManager.removeItem(at: vm.path!)
        
        Task {
            await remove(vm: vm)
        }
    }
    
    func clone(vm: UTMVirtualMachine) throws {
        let newName = newDefaultVMName(base: vm.title)
        let newPath = UTMVirtualMachine.virtualMachinePath(newName, inParentURL: documentsURL)
        
        try fileManager.copyItem(at: vm.path!, to: newPath)
        guard let newVM = UTMVirtualMachine(url: newPath) else {
            throw NSLocalizedString("Failed to clone VM.", comment: "UTMData")
        }
        
        DispatchQueue.main.async {
            self.virtualMachines.append(newVM)
        }
    }
    
    func newVM() {
        DispatchQueue.main.async {
            self.showSettingsModal = false
            self.showNewVMSheet = true
        }
    }
    
    func edit(vm: UTMVirtualMachine) {
        DispatchQueue.main.async {
            // show orphans for proper removal
            if let config = vm.config as? UTMQemuConfiguration {
                config.recoverOrphanedDrives()
            }
            self.selectedVM = vm
            self.showNewVMSheet = false
            // SwiftUI bug: cannot show modal at the same time as changing selected VM or it breaks
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                self.showSettingsModal = true
            }
        }
    }
    
    func computeSize(forVM: UTMVirtualMachine) -> Int64 {
        guard let path = forVM.path else {
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
    
    // MARK: - Export debug log
    
    func exportDebugLog(for config: UTMQemuConfiguration) throws -> VMShareItemModifier.ShareItem {
        guard let path = config.existingPath else {
            throw NSLocalizedString("No log found!", comment: "UTMData")
        }
        let srcLogPath = path.appendingPathComponent(UTMQemuConfiguration.debugLogName)
        return .debugLog(srcLogPath)
    }
    
    // MARK: - Import and Download VMs
    func copyUTM(at: URL, to: URL, move: Bool = false) throws {
        if move {
            try fileManager.moveItem(at: at, to: to)
        } else {
            try fileManager.copyItem(at: at, to: to)
        }
    }
    
    func importUTM(url: URL) async throws {
        guard url.isFileURL else { return }
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        logger.info("importing: \(url)")
        let fileBasePath = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let dest = documentsURL.appendingPathComponent(fileName, isDirectory: true)
        if let vm = virtualMachines.first(where: { vm -> Bool in
            guard let vmPath = vm.path else {
                return false
            }
            return vmPath.standardizedFileURL == url.standardizedFileURL
        }) {
            logger.info("found existing vm!")
            await select(vm: vm)
            return
        }
        // check if VM is valid
        guard let _ = UTMVirtualMachine(url: url) else {
            throw NSLocalizedString("Cannot import this VM. Either the configuration is invalid, created in a newer version of UTM, or on a platform that is incompatible with this version of UTM.", comment: "UTMData")
        }
        let vm: UTMVirtualMachine?
        if (fileBasePath.resolvingSymlinksInPath().path == documentsURL.appendingPathComponent("Inbox", isDirectory: true).path) {
            logger.info("moving from Inbox")
            try copyUTM(at: url, to: dest, move: true)
            vm = UTMVirtualMachine(url: dest)
        } else {
            #if os(macOS) // default behaviour on macOS is to import as shortcut
            logger.info("loading as a shortcut")
            vm = UTMVirtualMachine(url: url)
            vm?.isShortcut = true
            try await vm?.accessShortcut()
            #else
            logger.info("copying to Documents")
            try copyUTM(at: url, to: dest)
            vm = UTMVirtualMachine(url: dest)
            #endif
        }
        guard let vm = vm else {
            throw NSLocalizedString("Failed to parse imported VM.", comment: "UTMData")
        }
        await addNew(vm: vm)
    }
    
    func tryDownloadVM(_ components: URLComponents) {
        guard let urlParameter = components.queryItems?.first(where: { $0.name == "url" })?.value,
           urlParameter.contains(".zip"), let url = URL(string: urlParameter) else {
               return
        }
        Task {
            let task = UTMDownloadVMTask(for: url)
            do {
                await addNew(pendingVM: task.pendingVM)
                if let vm = try await task.download() {
                    await addNew(vm: vm)
                }
            } catch {
                await showErrorAlert(message: error.localizedDescription)
            }
            await remove(pendingVM: task.pendingVM)
        }
    }
    
    // MARK: - Disk drive functions
    
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
            selectedDiskImagesCache[name] = url
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
    
    func removeDrive(at index: Int, for config: UTMQemuConfiguration) throws {
        if let path = config.driveImagePath(for: index) {
            let fullPath = config.imagesPath.appendingPathComponent(path);
            if fileManager.fileExists(atPath: fullPath.path) {
                try fileManager.removeItem(at: fullPath)
            }
        }
        if let name = config.driveName(for: index) {
            selectedDiskImagesCache.removeValue(forKey: name)
        }
        DispatchQueue.main.async {
            config.removeDrive(at: index)
        }
    }
    
    private func commitDiskImages(for vm: UTMQemuVirtualMachine) throws {
        let drives = vm.drives
        defer {
            selectedDiskImagesCache.removeAll()
        }
        try selectedDiskImagesCache.forEach { name, url in
            let drive = drives.first { drive in
                drive.name == name
            }
            if let drive = drive {
                try vm.changeMedium(for: drive, url: url)
            }
        }
    }
    
    // MARK: - Networking
    
    func enableNetworking() {
        let task = URLSession.shared.dataTask(with: URL(string: "http://captive.apple.com")!)
        task.resume()
    }
    
    // MARK: - Helper functions
    
    private func recreate(vm: UTMVirtualMachine) {
        guard let path = vm.path else {
            logger.error("Attempting to refresh unsaved VM \(vm.title)")
            return
        }
        guard let newVM = UTMVirtualMachine(url: path) else {
            logger.debug("Cannot create new object for \(path.path)")
            return
        }
        DispatchQueue.main.async {
            //self.objectWillChange.send()
            if let index = self.virtualMachines.firstIndex(of: vm) {
                self.virtualMachines.remove(at: index)
                self.virtualMachines.insert(newVM, at: index)
            } else {
                self.virtualMachines.insert(newVM, at: 0)
            }
            if self.selectedVM == vm {
                self.selectedVM = newVM
            }
        }
    }
    
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
    
    #if swift(>=5.5)
    func busyWorkAsync(_ work: @escaping () async throws -> Void) {
        Task(priority: .userInitiated) {
            await setBusyIndicator(true)
            do {
                try await work()
            } catch {
                logger.error("\(error)")
                await showErrorAlert(message: error.localizedDescription)
            }
            await setBusyIndicator(false)
        }
    }
    #endif
    // MARK: - Automation Features
    
    func trySendText(_ vm: UTMVirtualMachine, urlComponents components: URLComponents) {
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
    
    func tryClickVM(_ vm: UTMVirtualMachine, urlComponents components: URLComponents) {
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
