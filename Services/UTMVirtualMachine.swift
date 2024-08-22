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

import Foundation
import Combine
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private let kUTMBundleExtension = "utm"
private let kScreenshotPeriodSeconds = 60.0
let kUTMBundleScreenshotFilename = "screenshot.png"
private let kUTMBundleViewFilename = "view.plist"

/// UTM virtual machine backend
protocol UTMVirtualMachine: AnyObject, Identifiable {
    associatedtype Capabilities: UTMVirtualMachineCapabilities
    associatedtype Configuration: UTMConfiguration
    
    /// Path where the .utm is stored
    var pathUrl: URL { get }
    
    /// True if the .utm is loaded outside of the default storage
    ///
    /// This indicates that we cannot access outside the container.
    var isShortcut: Bool { get }
    
    /// The VM is running in disposible mode
    ///
    /// This indicates that changes should not be saved.
    var isRunningAsDisposible: Bool { get }
    
    /// Set by caller to handle VM events
    var delegate: (any UTMVirtualMachineDelegate)? { get set }
    
    /// Set by caller to handle changes in `config` or `registryEntry`
    var onConfigurationChange: (() -> Void)? { get set }
    
    /// Set by caller to handle changes in `state` or `screenshot`
    var onStateChange: (() -> Void)?  { get set }
    
    /// Configuration for this VM
    var config: Configuration { get }
    
    /// Additional configuration on a short lived, per-host basis
    ///
    /// This includes display size, bookmarks to removable drives, etc.
    var registryEntry: UTMRegistryEntry { get }
    
    /// Current VM state
    var state: UTMVirtualMachineState { get }
    
    /// If non-null, is the most recent screenshot of the running VM
    var screenshot: UTMVirtualMachineScreenshot? { get }

    /// If non-null, `saveSnapshot` and `restoreSnapshot` will not work due to the reason specified
    var snapshotUnsupportedError: Error? { get }
    
    static func isVirtualMachine(url: URL) -> Bool
    
    /// Get name of UTM virtual machine from a file
    /// - Parameter url: File URL
    /// - Returns: The name of the VM
    static func virtualMachineName(for url: URL) -> String
    
    /// Get the path of a UTM virtual machine from a name and parent directory
    /// - Parameters:
    ///   - name: VM name
    ///   - parentUrl: Base directory file URL
    /// - Returns: URL of virtual machine
    static func virtualMachinePath(for name: String, in parentUrl: URL) -> URL
    
    /// Returns supported capabilities for this backend
    static var capabilities: Capabilities { get }
    
    /// Instantiate a new virtual machine
    /// - Parameters:
    ///   - packageUrl: Package where the virtual machine resides
    ///   - configuration: New virtual machine configuration
    ///   - isShortcut: Indicate that this package cannot be moved
    init(packageUrl: URL, configuration: Configuration, isShortcut: Bool) throws
    
    /// Discard any changes to configuration by reloading from disk
    /// - Parameter packageUrl: URL to reload from, if nil then use the existing package URL
    func reload(from packageUrl: URL?) throws
    
    /// Save .utm bundle to disk
    ///
    /// This will create a configuration file and any auxiliary data files if needed.
    func save() async throws
    
    /// Called when we save the config
    func updateRegistryFromConfig() async throws
    
    /// Called whenever the registry entry changes
    func updateConfigFromRegistry()
    
    /// Called when we have a duplicate UUID
    /// - Parameters:
    ///   - uuid: New UUID
    ///   - name: Optionally change name as well
    ///   - entry: Optionally copy data from an entry
    func changeUuid(to uuid: UUID, name: String?, copyingEntry entry: UTMRegistryEntry?)
    
    /// Starts the VM
    /// - Parameter options: Options for startup
    func start(options: UTMVirtualMachineStartOptions) async throws
    
    /// Stops the VM
    /// - Parameter method: How to handle the stop request
    func stop(usingMethod method: UTMVirtualMachineStopMethod) async throws
    
    /// Restarts the VM
    func restart() async throws
    
    /// Pauses the VM
    func pause() async throws
    
    /// Resumes the VM
    func resume() async throws
    
    /// Saves the current VM state
    /// - Parameter name: Optional snaphot name (default if nil)
    func saveSnapshot(name: String?) async throws
    
    /// Deletes the saved VM state
    /// - Parameter name: Optional snaphot name (default if nil)
    func deleteSnapshot(name: String?) async throws
    
    /// Restore saved VM state
    /// - Parameter name: Optional snaphot name (default if nil)
    func restoreSnapshot(name: String?) async throws
    
    /// Request a screenshot of the primary graphics device
    /// - Returns: true if successful and the screenshot will be in `screenshot`
    @discardableResult func takeScreenshot() async -> Bool
    
    /// If screenshot is modified externally, this must be called
    func reloadScreenshotFromFile() throws
}

/// Supported capabilities for a UTM backend
protocol UTMVirtualMachineCapabilities {
    /// The backend supports killing the VM process.
    var supportsProcessKill: Bool { get }
    
    /// The backend supports saving/restoring VM state.
    var supportsSnapshots: Bool { get }
    
    /// The backend supports taking screenshots.
    var supportsScreenshots: Bool { get }
    
    /// The backend supports running without persisting changes.
    var supportsDisposibleMode: Bool { get }
    
    /// The backend supports booting into recoveryOS.
    var supportsRecoveryMode: Bool { get }
    
    /// The backend supports remote sessions.
    var supportsRemoteSession: Bool { get }
}

/// Delegate for UTMVirtualMachine events
protocol UTMVirtualMachineDelegate: AnyObject {
    /// Called when VM state changes
    ///
    /// Will always be called from the main thread.
    /// - Parameters:
    ///   - vm: Virtual machine
    ///   - state: New state
    func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState)
    
    /// Called when VM errors
    ///
    /// Will always be called from the main thread.
    /// - Parameters:
    ///   - vm: Virtual machine
    ///   - message: Localized error message when supported, English message otherwise
    func virtualMachine(_ vm: any UTMVirtualMachine, didErrorWithMessage message: String)
    
    /// Called when VM installation updates progress
    /// - Parameters:
    ///   - vm: Virtual machine
    ///   - progress: Number between 0.0 and 1.0 indiciating installation progress
    func virtualMachine(_ vm: any UTMVirtualMachine, didUpdateInstallationProgress progress: Double)
    
    /// Called when VM successfully completes installation
    /// - Parameters:
    ///   - vm: Virtual machine
    ///   - success: True if installation is successful
    func virtualMachine(_ vm: any UTMVirtualMachine, didCompleteInstallation success: Bool)
}

/// Virtual machine state
enum UTMVirtualMachineState: Codable {
    case stopped
    case starting
    case started
    case pausing
    case paused
    case resuming
    case saving
    case restoring
    case stopping
}

/// Additional options for VM start
struct UTMVirtualMachineStartOptions: OptionSet, Codable {
    let rawValue: UInt
    
    /// Boot without persisting any changes.
    static let bootDisposibleMode = Self(rawValue: 1 << 0)
    /// Boot into recoveryOS (when supported).
    static let bootRecovery = Self(rawValue: 1 << 1)
    /// Start VDI session where a remote client will connect to.
    static let remoteSession = Self(rawValue: 1 << 2)
}

/// Method to stop the VM
enum UTMVirtualMachineStopMethod: Codable {
    /// Sends a request to the guest to shut down gracefully.
    case request
    /// Sends a hardware power down signal.
    case force
    /// Terminate the VM process.
    case kill
}

// MARK: - Class functions

extension UTMVirtualMachine {
    private static var fileManager: FileManager {
        FileManager.default
    }
    
    static func isVirtualMachine(url: URL) -> Bool {
        return url.pathExtension == kUTMBundleExtension
    }
    
    static func virtualMachineName(for url: URL) -> String {
        (fileManager.displayName(atPath: url.path) as NSString).deletingPathExtension
    }
    
    static func virtualMachinePath(for name: String, in parentUrl: URL) -> URL {
        let illegalFileNameCharacters = CharacterSet(charactersIn: ",/:\\?%*|\"<>")
        let name = name.components(separatedBy: illegalFileNameCharacters).joined(separator: "-")
        return parentUrl.appendingPathComponent(name).appendingPathExtension(kUTMBundleExtension)
    }
    
    /// Instantiate a new VM from a new configuration
    /// - Parameters:
    ///   - configuration: New configuration
    ///   - destinationUrl: Directory to store VM
    init(newForConfiguration configuration: Self.Configuration, destinationUrl: URL) throws {
        let packageUrl = Self.virtualMachinePath(for: configuration.information.name, in: destinationUrl)
        try self.init(packageUrl: packageUrl, configuration: configuration, isShortcut: false)
    }
}

// MARK: - Snapshots

extension UTMVirtualMachine {
    func saveSnapshot(name: String?) async throws {
        throw UTMVirtualMachineError.notImplemented
    }
    
    func deleteSnapshot(name: String?) async throws {
        throw UTMVirtualMachineError.notImplemented
    }
    
    func restoreSnapshot(name: String?) async throws {
        throw UTMVirtualMachineError.notImplemented
    }
}

// MARK: - Screenshot

struct UTMVirtualMachineScreenshot {
    let image: PlatformImage
    let pngData: Data?

    init?(contentsOfURL url: URL) {
        #if canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        #elseif canImport(UIKit)
        guard let image = UIImage(contentsOfURL: url) else {
            return nil
        }
        #endif
        self.image = image
        self.pngData = Self.createData(from: image)
    }

    init(wrapping image: PlatformImage) {
        self.image = image
        self.pngData = Self.createData(from: image)
    }

    private static func createData(from image: PlatformImage) -> Data? {
        #if canImport(AppKit)
        guard let cgref = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let newrep = NSBitmapImageRep(cgImage: cgref)
        newrep.size = image.size
        return newrep.representation(using: .png, properties: [:])
        #elseif canImport(UIKit)
        return image.pngData()
        #endif
    }
}

extension UTMVirtualMachine {
    private var isScreenshotSaveEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "NoSaveScreenshot")
    }
    
    private var screenshotUrl: URL {
        pathUrl.appendingPathComponent(kUTMBundleScreenshotFilename)
    }
    
    func startScreenshotTimer() -> Timer {
        // delete existing screenshot if required
        if !isScreenshotSaveEnabled && !isRunningAsDisposible {
            try? deleteScreenshot()
        }
        let timer = Timer(timeInterval: kScreenshotPeriodSeconds, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.state == .started {
                Task { @MainActor in
                    await self.takeScreenshot()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .default)
        return timer
    }
    
    func loadScreenshot() -> UTMVirtualMachineScreenshot? {
        UTMVirtualMachineScreenshot(contentsOfURL: screenshotUrl)
    }
    
    func saveScreenshot() throws {
        guard isScreenshotSaveEnabled && !isRunningAsDisposible else {
            return
        }
        guard let screenshot = screenshot else {
            return
        }
        try screenshot.pngData?.write(to: screenshotUrl)
    }
    
    func deleteScreenshot() throws {
        try Self.fileManager.removeItem(at: screenshotUrl)
    }
    
    @MainActor func takeScreenshot() async -> Bool {
        return false
    }
}

// MARK: - Save UTM

@MainActor extension UTMVirtualMachine {
    func save() async throws {
        let existingPath = pathUrl
        let newPath = Self.virtualMachinePath(for: config.information.name, in: existingPath.deletingLastPathComponent())
        try await config.save(to: existingPath)
        try await updateRegistryFromConfig()
        let hasRenamed: Bool
        if !isShortcut && existingPath.path != newPath.path {
            try await Task.detached {
                try Self.fileManager.moveItem(at: existingPath, to: newPath)
            }.value
            hasRenamed = true
        } else {
            hasRenamed = false
        }
        // reload the config if we renamed in order to point all the URLs to the right path
        if hasRenamed {
            try reload(from: newPath)
            try await updateRegistryBasics() // update bookmark
        }
        // update last modified date
        try? updateLastModified()
    }
    
    /// Set the package's last modified time
    /// - Parameter date: Last modified date
    nonisolated func updateLastModified(to date: Date = Date()) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: pathUrl.path)
    }
}

// MARK: - Registry functions

@MainActor extension UTMVirtualMachine {
    nonisolated func loadRegistry() -> UTMRegistryEntry {
        let registryEntry = UTMRegistry.shared.entry(for: self)
        // migrate legacy view state
        let viewStateUrl = pathUrl.appendingPathComponent(kUTMBundleViewFilename)
        registryEntry.migrateUnsafe(viewStateURL: viewStateUrl)
        return registryEntry
    }
    
    /// Default implementation
    func updateRegistryFromConfig() async throws {
        try await updateRegistryBasics()
    }
    
    /// Called when we save the config
    func updateRegistryBasics() async throws {
        if registryEntry.uuid != id {
            changeUuid(to: id, name: nil, copyingEntry: registryEntry)
        }
        registryEntry.name = name
        let oldPath = registryEntry.package.path
        let oldRemoteBookmark = registryEntry.package.remoteBookmark
        registryEntry.package = try UTMRegistryEntry.File(url: pathUrl)
        if registryEntry.package.path == oldPath {
            registryEntry.package.remoteBookmark = oldRemoteBookmark
        }
    }
}

// MARK: - Identity

extension UTMVirtualMachine {
    var id: UUID {
        config.information.uuid
    }
    
    var name: String {
        config.information.name
    }
}

// MARK: - Errors

enum UTMVirtualMachineError: Error {
    case notImplemented
}

extension UTMVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return NSLocalizedString("Not implemented.", comment: "UTMVirtualMachine")
        }
    }
}

// MARK: - Non-asynchronous version (to be removed)

extension UTMVirtualMachine {
    func requestVmStart(options: UTMVirtualMachineStartOptions = []) {
        Task {
            do {
                try await start(options: options)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmStop(force: Bool = false) {
        Task {
            do {
                try await stop(usingMethod: force ? .kill : .force)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmReset() {
        Task {
            do {
                try await restart()
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmPause(save: Bool = false) {
        Task {
            do {
                try await pause()
                if save {
                    try await saveSnapshot(name: nil)
                }
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmSaveState() {
        Task {
            do {
                try await saveSnapshot(name: nil)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmDeleteState() {
        Task {
            do {
                try await deleteSnapshot(name: nil)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestVmResume() {
        Task {
            do {
                try await resume()
                try? await deleteSnapshot(name: nil)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
    
    func requestGuestPowerDown() {
        Task {
            do {
                try await stop(usingMethod: .request)
            } catch {
                delegate?.virtualMachine(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }
}
