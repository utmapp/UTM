//
// Copyright © 2024 osy. All rights reserved.
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
#elseif os(iOS)
import UIKit
#endif

class UTMInstaller {
    enum InstallationError: Error, LocalizedError {
        case notAuthorized
        case invalidBundle
        case installationFailed(String)
        case backupFailed
        case platformNotSupported
        case insufficientDiskSpace
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Installation not authorized"
            case .invalidBundle:
                return "Invalid application bundle"
            case .installationFailed(let reason):
                return "Installation failed: \(reason)"
            case .backupFailed:
                return "Failed to create backup"
            case .platformNotSupported:
                return "Platform not supported for automatic updates"
            case .insufficientDiskSpace:
                return "Insufficient disk space for installation"
            }
        }
    }
    
    func installUpdate(from downloadURL: URL) async throws {
        #if os(macOS)
        try await installMacOSUpdate(from: downloadURL)
        #elseif os(iOS)
        try await installiOSUpdate(from: downloadURL)
        #else
        throw InstallationError.platformNotSupported
        #endif
    }
    
    #if os(macOS)
    private func installMacOSUpdate(from downloadURL: URL) async throws {
        try validateDownloadedFile(at: downloadURL)
        
        try checkDiskSpace(for: downloadURL)
        
        let backupURL = try createBackup()
        
        do {
            if downloadURL.pathExtension.lowercased() == "dmg" {
                try await installFromDMG(downloadURL)
            } else {
                throw InstallationError.invalidBundle
            }
            
            try restartApplication()
            
        } catch {
            // Rollback on failure
            try? rollbackFromBackup(backupURL)
            throw InstallationError.installationFailed(error.localizedDescription)
        }
    }
    
    private func validateDownloadedFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InstallationError.invalidBundle
        }

        // additional validation could be added here:
        // - code signature verification
        // - bundle structure validation
        // - checksum verification
    }
    
    private func checkDiskSpace(for downloadURL: URL) throws {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: downloadURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // estimate required space (file size + extraction space + backup space)
        let requiredSpace = fileSize * 3
        
        if let availableSpace = try? FileManager.default.url(for: .applicationDirectory, in: .localDomainMask, appropriateFor: nil, create: false).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
            if availableSpace < requiredSpace {
                throw InstallationError.insufficientDiskSpace
            }
        }
    }
    
    private func createBackup() throws -> URL {
        let currentAppURL = Bundle.main.bundleURL
        
        let backupDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("UTMBackup-\(UUID().uuidString)")
        let backupURL = backupDirectory.appendingPathComponent(currentAppURL.lastPathComponent)
        
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: currentAppURL, to: backupURL)
        
        return backupURL
    }
    
    private func installFromDMG(_ dmgURL: URL) async throws {
        let mountPoint = try await mountDMG(dmgURL)
        
        defer {
            try unmountDMG(mountPoint)
        }
        
        let appURL = try findAppBundle(in: mountPoint)
        
        try installAppBundle(from: appURL)
    }
    
    private func installFromZIP(_ zipURL: URL) async throws {
        let extractionURL = try await extractZIP(zipURL)
        
        defer {
            try? FileManager.default.removeItem(at: extractionURL)
        }
        
        let appURL = try findAppBundle(in: extractionURL)
        
        try installAppBundle(from: appURL)
    }
    
    private func mountDMG(_ dmgURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-quiet", "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw InstallationError.installationFailed("Failed to mount DMG")
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let systemEntities = plist["system-entities"] as? [[String: Any]] else {
            throw InstallationError.installationFailed("Failed to parse mount output")
        }
        
        for entity in systemEntities {
            if let mountPoint = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPoint)
            }
        }
        
        throw InstallationError.installationFailed("No mount point found")
    }
    
    private func unmountDMG(_ mountPoint: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        
        try process.run()
        process.waitUntilExit()
    }
    
    private func extractZIP(_ zipURL: URL) async throws -> URL {
        let extractionURL = FileManager.default.temporaryDirectory.appendingPathComponent("UTMExtraction-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractionURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw InstallationError.installationFailed("Failed to extract ZIP")
        }
        
        return extractionURL
    }
    
    private func findAppBundle(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        
        for item in contents {
            if item.pathExtension == "app" {
                return item
            }
            
            // look in subdirectories
            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                if let appURL = try? findAppBundle(in: item) {
                    return appURL
                }
            }
        }
        
        throw InstallationError.invalidBundle
    }
    
    private func installAppBundle(from sourceURL: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        
        try FileManager.default.removeItem(at: currentAppURL)
        
        try FileManager.default.copyItem(at: sourceURL, to: currentAppURL)
        
        try setExecutablePermissions(for: currentAppURL)
    }
    
    private func setExecutablePermissions(for appURL: URL) throws {
        let executableURL = appURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(appURL.deletingPathExtension().lastPathComponent)
        
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o755
        ]
        
        try FileManager.default.setAttributes(attributes, ofItemAtPath: executableURL.path)
    }
    
    private func rollbackFromBackup(_ backupURL: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        
        try? FileManager.default.removeItem(at: currentAppURL)
        
        try FileManager.default.copyItem(at: backupURL, to: currentAppURL)
    }
    
    private func restartApplication() throws {
        let appURL = Bundle.main.bundleURL
        
        // create a script to restart the app after a delay
        let script = """
        #!/bin/bash
        sleep 2
        open "\(appURL.path)"
        """
        
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("restart_utm.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // make script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        // execute script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.launch()
        
        // exit current app
        NSApp.terminate(nil)
    }
    
    #endif
    
    #if os(iOS)
    private func installiOSUpdate(from downloadURL: URL) async throws {
        // iOS automatic installation is limited due to App Store restrictions
        // Different approaches based on distribution method:
        
        if isAppStoreVersion() {
            // Redirect to App Store
            try await redirectToAppStore()
        } else if isTestFlightVersion() {
            // Show TestFlight update notification
            try await showTestFlightUpdate()
        } else {
            // Side-loaded version - guide user through re-installation
            try await guideSideloadedUpdate(from: downloadURL)
        }
    }
    
    private func isAppStoreVersion() -> Bool {
        // Check if app was installed from App Store
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }
    
    private func isTestFlightVersion() -> Bool {
        // Check for TestFlight installation
        return Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }
    
    private func redirectToAppStore() async throws {
        guard let appID = Bundle.main.infoDictionary?["UTMAppStoreID"] as? String,
              let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)") else {
            throw InstallationError.installationFailed("Cannot construct App Store URL")
        }
        
        await UIApplication.shared.open(url)
    }
    
    private func showTestFlightUpdate() async throws {
        guard let url = URL(string: "itms-beta://") else {
            throw InstallationError.installationFailed("Cannot open TestFlight")
        }
        
        await UIApplication.shared.open(url)
    }
    
    private func guideSideloadedUpdate(from downloadURL: URL) async throws {
        // For side-loaded apps, we can only guide the user through manual installation
        // This would typically involve showing instructions to re-sign and install the IPA
        throw InstallationError.platformNotSupported
    }
    #endif
}
