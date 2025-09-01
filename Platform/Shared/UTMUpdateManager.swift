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

import SwiftUI
import Foundation
import Combine

@MainActor
class UTMUpdateManager: UTMReleaseHelper {
    static let shared = UTMUpdateManager()
    
    // MARK: - Update-specific Published Properties
    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var updateInfo: UpdateInfo?
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var isInstalling: Bool = false
    @Published var isCheckingForUpdates: Bool = false
    @Published var updateError: UpdateError?
    @Published var showUpdateDialog: Bool = false
    
    // MARK: - Settings
    @AppStorage("AutoCheckForUpdates") private var autoCheckForUpdates: Bool = true
    @AppStorage("AutoDownloadUpdates") private var autoDownloadUpdates: Bool = false
    @AppStorage("UpdateCheckInterval") private var updateCheckInterval: TimeInterval = 86400 // 24 hours
    @AppStorage("LastUpdateCheck") private var lastUpdateCheckData: Data?
    @AppStorage("SkippedVersion") private var skippedVersion: String?
    @AppStorage("NotifyPreRelease") private var notifyPreRelease: Bool = false
    @AppStorage("UpdateChannel") private var updateChannelRawValue: String = UpdateChannel.stable.rawValue
    
    private var lastUpdateCheck: Date? {
        get {
            guard let data = lastUpdateCheckData else { return nil }
            return try? JSONDecoder().decode(Date.self, from: data)
        }
        set {
            lastUpdateCheckData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // Public accessor for lastUpdateCheck
    var lastUpdateCheckDate: Date? {
        return lastUpdateCheck
    }
    
    private var updateChannel: UpdateChannel {
        get { UpdateChannel(rawValue: updateChannelRawValue) ?? .stable }
        set { updateChannelRawValue = newValue.rawValue }
    }
    
    // MARK: - Private Properties
    private var updateCheckTimer: Timer?
    private var downloadManager: UTMDownloadManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Data Structures
    struct UpdateInfo: Codable, Identifiable {
        let id = UUID()
        let version: String
        let releaseDate: Date
        let downloadURL: URL
        let releaseNotes: String
        let fileSize: Int64
        let minimumSystemVersion: String
        let isCritical: Bool
        let isPrerelease: Bool
        let assets: [ReleaseAsset]
        
        struct ReleaseAsset: Codable {
            let name: String
            let downloadURL: URL
            let size: Int64
            let contentType: String
        }
    }
    
    enum UpdateChannel: String, CaseIterable, Codable {
        case stable = "stable"
        case beta = "beta"
        case all = "all"
        
        var displayName: String {
            switch self {
            case .stable: return NSLocalizedString("Stable", comment: "UTMUpdateManager")
            case .beta: return NSLocalizedString("Beta", comment: "UTMUpdateManager")
            case .all: return NSLocalizedString("All Releases", comment: "UTMUpdateManager")
            }
        }
    }
    
    enum UpdateError: Error, LocalizedError {
        case networkUnavailable
        case downloadFailed(String)
        case verificationFailed
        case installationFailed(String)
        case insufficientSpace
        case unsupportedVersion
        case invalidResponse
        case noUpdateAvailable
        
        var errorDescription: String? {
            switch self {
            case .networkUnavailable:
                return NSLocalizedString("Network connection unavailable", comment: "UTMUpdateManager")
            case .downloadFailed(let reason):
                return String.localizedStringWithFormat(NSLocalizedString("Download failed: %@", comment: "UTMUpdateManager"), reason)
            case .verificationFailed:
                return NSLocalizedString("Update verification failed", comment: "UTMUpdateManager")
            case .installationFailed(let reason):
                return String.localizedStringWithFormat(NSLocalizedString("Installation failed: %@", comment: "UTMUpdateManager"), reason)
            case .insufficientSpace:
                return NSLocalizedString("Insufficient disk space for update", comment: "UTMUpdateManager")
            case .unsupportedVersion:
                return NSLocalizedString("This update requires a newer system version", comment: "UTMUpdateManager")
            case .invalidResponse:
                return NSLocalizedString("Invalid response from update server", comment: "UTMUpdateManager")
            case .noUpdateAvailable:
                return NSLocalizedString("No update available", comment: "UTMUpdateManager")
            }
        }
    }
    
    override init() {
        super.init()
        setupUpdateChecking()
    }
    
    // MARK: - Update Checking
    func checkForUpdates(force: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        updateError = nil
        
        defer {
            isCheckingForUpdates = false
            lastUpdateCheck = Date()
        }
        
        do {
            let updateInfo = try await fetchLatestRelease()
            await handleUpdateCheckResult(updateInfo)
        } catch {
            updateError = error as? UpdateError ?? .networkUnavailable
            logger.error("Update check failed: \(error.localizedDescription)")
        }
    }
    
    private func fetchLatestRelease() async throws -> UpdateInfo? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "UTM/\(currentVersion)"
        ]
        
        let session = URLSession(configuration: configuration)
        let url: String
        
        switch updateChannel {
        case .stable:
            url = "https://api.github.com/repos/utmapp/UTM/releases/latest"
        case .beta, .all:
            url = "https://api.github.com/repos/utmapp/UTM/releases"
        }
        
        let (data, response) = try await session.data(from: URL(string: url)!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.invalidResponse
        }
        
        if updateChannel == .stable {
            return try parseLatestRelease(data)
        } else {
            return try parseReleases(data)
        }
    }
    
    private func parseLatestRelease(_ data: Data) throws -> UpdateInfo? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.invalidResponse
        }
        
        return try parseReleaseJSON(json)
    }
    
    private func parseReleases(_ data: Data) throws -> UpdateInfo? {
        guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw UpdateError.invalidResponse
        }
        
        for release in releases {
            if let updateInfo = try parseReleaseJSON(release) {
                let isPrerelease = release["prerelease"] as? Bool ?? false
                
                switch updateChannel {
                case .stable:
                    if !isPrerelease {
                        return updateInfo
                    }
                case .beta:
                    if !isPrerelease || isPrerelease {
                        return updateInfo
                    }
                case .all:
                    return updateInfo
                }
            }
        }
        
        return nil
    }
    
    private func parseReleaseJSON(_ json: [String: Any]) throws -> UpdateInfo? {
        guard let tagName = json["tag_name"] as? String,
              let body = json["body"] as? String,
              let publishedAt = json["published_at"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            return nil
        }
        
        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        
        // Check if this version is newer than current
        if !isVersionNewer(version, than: currentVersion) {
            return nil
        }
        
        // Check if user has skipped this version
        if skippedVersion == version {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let releaseDate = dateFormatter.date(from: publishedAt) ?? Date()
        
        let releaseAssets = assets.compactMap { asset -> UpdateInfo.ReleaseAsset? in
            guard let name = asset["name"] as? String,
                  let downloadURLString = asset["browser_download_url"] as? String,
                  let downloadURL = URL(string: downloadURLString),
                  let size = asset["size"] as? Int64,
                  let contentType = asset["content_type"] as? String else {
                return nil
            }
            
            return UpdateInfo.ReleaseAsset(
                name: name,
                downloadURL: downloadURL,
                size: size,
                contentType: contentType
            )
        }
        
        // Find appropriate asset for current platform
        guard let downloadAsset = findAppropriateAsset(from: releaseAssets) else {
            return nil
        }
        
        let isPrerelease = json["prerelease"] as? Bool ?? false
        let isCritical = body.lowercased().contains("critical")
        
        return UpdateInfo(
            version: version,
            releaseDate: releaseDate,
            downloadURL: downloadAsset.downloadURL,
            releaseNotes: body,
            fileSize: downloadAsset.size,
            minimumSystemVersion: extractMinimumSystemVersion(from: body),
            isCritical: isCritical,
            isPrerelease: isPrerelease,
            assets: releaseAssets
        )
    }
    
    private func findAppropriateAsset(from assets: [UpdateInfo.ReleaseAsset]) -> UpdateInfo.ReleaseAsset? {
        #if os(macOS)
        // Look for macOS app bundle
        return assets.first { asset in
            (asset.name.hasSuffix(".dmg"))
        }
        #elseif os(iOS)
        // Look for iOS IPA (UTM.ipa)
        return assets.first { asset in
            asset.name.lowercased() == "utm.ipa"
        }
        #else
        return nil
        #endif
    }
    
    private func extractMinimumSystemVersion(from releaseNotes: String) -> String {
        // Try to extract minimum system version from release notes
        let patterns = [
            #"(?:macOS|iOS)\s+(\d+(?:\.\d+)*)\+?"#,
            #"(?:requires|minimum)\s+(?:macOS|iOS)\s+(\d+(?:\.\d+)*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: releaseNotes, range: NSRange(releaseNotes.startIndex..., in: releaseNotes)) {
                if let range = Range(match.range(at: 1), in: releaseNotes) {
                    return String(releaseNotes[range])
                }
            }
        }
        
        #if os(macOS)
        return "11.0"
        #elseif os(iOS)
        return "14.0"
        #else
        return "1.0"
        #endif
    }
    
    private func isVersionNewer(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Part = i < v1Components.count ? v1Components[i] : 0
            let v2Part = i < v2Components.count ? v2Components[i] : 0
            
            if v1Part > v2Part {
                return true
            } else if v1Part < v2Part {
                return false
            }
        }
        
        return false
    }
    
    private func handleUpdateCheckResult(_ updateInfo: UpdateInfo?) async {
        if let updateInfo = updateInfo {
            self.updateInfo = updateInfo
            self.latestVersion = updateInfo.version
            self.isUpdateAvailable = true
            
            // Check if this version is skipped
            let isSkipped = skippedVersion == updateInfo.version
            
            // Show update dialog if not skipped and not auto-downloading
            if !isSkipped && (!autoDownloadUpdates || updateInfo.isPrerelease) {
                showUpdateDialog = true
                NotificationCenter.default.post(name: NSNotification.Name("UpdateAvailable"), object: nil)
            }
            
            // Auto-download if enabled
            if autoDownloadUpdates && !updateInfo.isPrerelease && !isSkipped {
                await startDownload()
            }
        } else {
            self.isUpdateAvailable = false
            self.updateInfo = nil
            self.latestVersion = ""
        }
    }
    
    // MARK: - Update Downloading
    func startDownload() async {
        guard let updateInfo = updateInfo,
              !isDownloading,
              !isInstalling else { return }
        
        isDownloading = true
        updateError = nil
        
        do {
            downloadManager = UTMDownloadManager()
            
            // Observe download progress
            downloadManager?.$downloadProgress
                .receive(on: DispatchQueue.main)
                .assign(to: \.downloadProgress, on: self)
                .store(in: &cancellables)
            
            let downloadedURL = try await downloadManager?.downloadUpdate(from: updateInfo.downloadURL)
            
            if let downloadedURL = downloadedURL {
                // Verify download
                try await verifyDownload(at: downloadedURL, expectedSize: updateInfo.fileSize)
                
                // Start installation
                await startInstallation(from: downloadedURL)
            }
        } catch {
            updateError = error as? UpdateError ?? .downloadFailed(error.localizedDescription)
            isDownloading = false
        }
    }
    
    func cancelDownload() {
        downloadManager?.cancelDownload()
        downloadManager = nil
        isDownloading = false
        downloadProgress = 0.0
    }
    
    private func verifyDownload(at url: URL, expectedSize: Int64) async throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard fileSize == expectedSize else {
            throw UpdateError.verificationFailed
        }
        
        // Additional integrity checks could be added here
        // such as checksum verification
    }
    
    // MARK: - Update Installation
    private func startInstallation(from url: URL) async {
        isInstalling = true
        
        do {
            let installer = UTMInstaller()
            try await installer.installUpdate(from: url)
            
            // Installation guidance shown - reset state but don't restart
            await handleInstallationGuidanceShown()
        } catch {
            updateError = error as? UpdateError ?? .installationFailed(error.localizedDescription)
            isInstalling = false
        }
    }
    
    private func handleInstallationGuidanceShown() async {
        // Clean up downloaded file
        if let downloadManager = downloadManager {
            downloadManager.cleanupDownload()
        }
        
        // Reset downloading/installing state, but keep update info visible
        isDownloading = false
        isInstalling = false
        downloadProgress = 0.0
        
        // Keep isUpdateAvailable true and updateInfo to allow user to try again if needed
        // The user will manually dismiss this when they complete the installation
    }
    
    // MARK: - Public Interface
    func skipVersion(_ version: String) {
        skippedVersion = version
        isUpdateAvailable = false
        updateInfo = nil
    }
    
    func downloadAndInstall() async {
        await startDownload()
    }
    
    func skipVersion() {
        if let updateInfo = updateInfo {
            skippedVersion = updateInfo.version
            showUpdateDialog = false
            isUpdateAvailable = false
        }
    }
    
    func remindLater() {
        showUpdateDialog = false
        // Reset last check time to trigger another check after interval
        lastUpdateCheck = Date()
    }
    
    // MARK: - Automatic Update Checking
    private func setupUpdateChecking() {
        guard autoCheckForUpdates else { return }
        
        // Check on app launch if enough time has passed
        if let lastCheck = lastUpdateCheck,
           Date().timeIntervalSince(lastCheck) < updateCheckInterval {
            return
        }
        
        // Perform initial check
        Task {
            await checkForUpdates()
        }
        
        // Setup periodic checking
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: updateCheckInterval, repeats: true) { _ in
            Task {
                await self.checkForUpdates()
            }
        }
    }
    
    deinit {
        updateCheckTimer?.invalidate()
    }
}

// MARK: - Extensions for String Array
extension Array where Element == String {
    var id: String {
        return self.joined(separator: "\n")
    }
}
