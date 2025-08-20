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
        case mountFailed
        
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
            case .mountFailed:
                return "Failed to mount DMG file"
            }
        }
    }
    
    func installUpdate(from downloadURL: URL) async throws {
        #if os(macOS)
        try await openDMGAndShowInstructions(from: downloadURL)
        #elseif os(iOS)
        try await installiOSUpdate(from: downloadURL)
        #else
        throw InstallationError.platformNotSupported
        #endif
    }
    
    #if os(macOS)
    private func openDMGAndShowInstructions(from downloadURL: URL) async throws {
        // Mount the DMG
        let mountPoint = try await mountDMG(downloadURL)
        
        // Show the mounted volume in Finder
        try showMountedDMGInFinder(mountPoint)
        
        // Show installation instructions to the user
        try showInstallationInstructions()
    }
    
    private func showMountedDMGInFinder(_ mountPoint: URL) throws {
        NSWorkspace.shared.open(mountPoint)
    }
    
    private func showInstallationInstructions() throws {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Installation Instructions", comment: "UTMInstaller")
            alert.informativeText = NSLocalizedString("Please follow these steps to complete the update:\n\n1. Save any unsaved work in your virtual machines\n2. Quit UTM completely\n3. Drag the new UTM.app from the opened DMG to your Applications folder (replace the existing version)\n4. Restart UTM\n\nThe DMG will remain mounted until you manually eject it.", comment: "UTMInstaller")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "UTMInstaller"))
            alert.addButton(withTitle: NSLocalizedString("Quit UTM Now", comment: "UTMInstaller"))
            alert.alertStyle = .informational
            
            let response = alert.runModal()
            
            if response == .alertSecondButtonReturn {
                // User chose to quit UTM now
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    
    private func mountDMG(_ dmgURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-quiet", "-plist"]

        print("process.arguments: \(process.arguments ?? [""])")
        print("process.environment: \(process.environment ?? [:])")
        print("Mounting DMG at: \(dmgURL.path)")
        
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()

        print("process.terminationStatus: \(process.terminationStatus)")
        
        guard process.terminationStatus == 0 else {
            throw InstallationError.mountFailed
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let systemEntities = plist["system-entities"] as? [[String: Any]] else {
            throw InstallationError.mountFailed
        }
        
        for entity in systemEntities {
            if let mountPoint = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPoint)
            }
        }
        
        throw InstallationError.mountFailed
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
