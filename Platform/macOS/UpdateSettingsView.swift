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

// MARK: - Date Formatting Extension
extension Date {
    var abbreviatedDateString: String {
        if #available(macOS 12, *) {
            return self.formatted(date: .abbreviated, time: .omitted)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}

struct UpdateSettingsView: View {
    @StateObject private var updateManager = UTMUpdateManager.shared
    @AppStorage("AutoCheckForUpdates") var autoCheckForUpdates = true
    @AppStorage("AutoDownloadUpdates") var autoDownloadUpdates = false
    @AppStorage("NotifyPreRelease") var notifyPreRelease = false
    @AppStorage("UpdateChannel") var updateChannelRaw: String = UTMUpdateManager.UpdateChannel.stable.rawValue
    
    private var updateChannel: UTMUpdateManager.UpdateChannel {
        UTMUpdateManager.UpdateChannel(rawValue: updateChannelRaw) ?? .stable
    }
    
    var body: some View {
        Form {
            
            Section(header: Text(NSLocalizedString("Update Preferences", comment: "UpdateSettingsView"))) {
                
                Toggle(NSLocalizedString("Automatically check for updates", comment: "UpdateSettingsView"), isOn: $autoCheckForUpdates)
                    
                    .help(NSLocalizedString("UTM will check for updates periodically in the background", comment: "UpdateSettingsView"))
                
                
                Toggle(NSLocalizedString("Automatically download updates", comment: "UpdateSettingsView"), isOn: $autoDownloadUpdates)
                    .disabled(!autoCheckForUpdates)
                    
                    .help(NSLocalizedString("Updates will be downloaded automatically when available", comment: "UpdateSettingsView"))
                
                
                Picker(NSLocalizedString("Update Channel", comment: "UpdateSettingsView"), selection: Binding(
                    get: { updateChannel },
                    set: { updateChannelRaw = $0.rawValue }
                )) {
                    ForEach(UTMUpdateManager.UpdateChannel.allCases, id: \.self) { channel in
                        Text(channel.displayName).tag(channel)
                    }
                }
                
                .help(NSLocalizedString("Choose which types of releases to receive", comment: "UpdateSettingsView"))
                
                
                Toggle(NSLocalizedString("Include pre-release versions", comment: "UpdateSettingsView"), isOn: $notifyPreRelease)
                    .disabled(updateChannel != .all)
                    
                    .help(NSLocalizedString("Include beta and pre-release versions in update checks", comment: "UpdateSettingsView"))
            }
            
            
            Section(header: Text(NSLocalizedString("Update Check", comment: "UpdateSettingsView"))) {
                HStack {
                    VStack(alignment: .leading) {
                        
                        Text(NSLocalizedString("Check for updates:", comment: "UpdateSettingsView"))
                        if updateManager.isCheckingForUpdates {
                            
                            Text(NSLocalizedString("Checking...", comment: "UpdateSettingsView"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let error = updateManager.updateError {
                            
                            Text(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "UpdateSettingsView"), error.localizedDescription))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                    
                    Button(NSLocalizedString("Check Now", comment: "UpdateSettingsView")) {
                        Task {
                            await updateManager.checkForUpdates(force: true)
                        }
                    }
                    .disabled(updateManager.isCheckingForUpdates)
                }
            }
            
            if let updateInfo = updateManager.updateInfo {
                UpdateAvailableSection(updateInfo: updateInfo, updateManager: updateManager)
            }
            
            
            Section(header: Text(NSLocalizedString("Current Version", comment: "UpdateSettingsView"))) {
                HStack {
                    
                    Text(NSLocalizedString("Version", comment: "UpdateSettingsView"))
                    Spacer()
                    Text(updateManager.currentVersion)
                        .foregroundColor(.secondary)
                }
                
                if let lastCheck = updateManager.lastUpdateCheckDate {
                    HStack {
                        
                        Text(NSLocalizedString("Last checked", comment: "UpdateSettingsView"))
                        Spacer()
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                if updateManager.isUpdateAvailable {
                    HStack {
                        
                        Text(NSLocalizedString("Status", comment: "UpdateSettingsView"))
                        Spacer()
                        
                        Label(NSLocalizedString("Update Available", comment: "UpdateSettingsView"), systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                } else if !updateManager.isCheckingForUpdates && updateManager.updateError == nil {
                    HStack {
                        
                        Text(NSLocalizedString("Status", comment: "UpdateSettingsView"))
                        Spacer()
                        
                        Label(NSLocalizedString("Up to Date", comment: "UpdateSettingsView"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .onAppear {
            // perform initial update check if it's been a while (more than 1 hour)
            if updateManager.lastUpdateCheckDate == nil || 
               Date().timeIntervalSince(updateManager.lastUpdateCheckDate ?? Date.distantPast) > 3600 {
                Task {
                    await updateManager.checkForUpdates()
                }
            }
        }
    }
}

struct UpdateAvailableSection: View {
    let updateInfo: UTMUpdateManager.UpdateInfo
    @ObservedObject var updateManager: UTMUpdateManager
    @State private var showReleaseNotes = false
    
    var body: some View {
        
        Section(header: Text(NSLocalizedString("Update Available", comment: "UpdateSettingsView"))) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    
                    Label(String.localizedStringWithFormat(NSLocalizedString("UTM %@", comment: "UpdateSettingsView"), updateInfo.version), systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    if updateInfo.isCritical {
                        
                        Label(NSLocalizedString("Critical", comment: "UpdateSettingsView"), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if updateInfo.isPrerelease {
                        
                        Label(NSLocalizedString("Beta", comment: "UpdateSettingsView"), systemImage: "hammer.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text(String.localizedStringWithFormat(NSLocalizedString("Released: %@", comment: "UpdateSettingsView"), updateInfo.releaseDate.abbreviatedDateString))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                
                Text(String.localizedStringWithFormat(NSLocalizedString("Size: %@", comment: "UpdateSettingsView"), ByteCountFormatter.string(fromByteCount: updateInfo.fileSize, countStyle: .file)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if updateManager.isDownloading {
                    ProgressView(value: updateManager.downloadProgress) {
                        HStack {
                            
                            Text(NSLocalizedString("Downloading...", comment: "UpdateSettingsView"))
                            Spacer()
                            Text("\(Int(updateManager.downloadProgress * 100))%")
                        }
                        .font(.caption)
                    }
                } else if updateManager.isInstalling {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        
                        Text(NSLocalizedString("Preparing installation...", comment: "UpdateSettingsView"))
                            .font(.caption)
                    }
                }
                
                HStack {
                    
                    Button(NSLocalizedString("Release Notes", comment: "UpdateSettingsView")) {
                        showReleaseNotes = true
                    }
                    
                    
                    Button(NSLocalizedString("Skip This Version", comment: "UpdateSettingsView")) {
                        updateManager.skipVersion(updateInfo.version)
                    }
                    
                    Spacer()
                    
                    if updateManager.isDownloading {
                        
                        Button(NSLocalizedString("Cancel", comment: "UpdateSettingsView")) {
                            updateManager.cancelDownload()
                        }
                    } else if !updateManager.isInstalling {
                        if #available(macOS 12.0, *) {
                            
                            Button(NSLocalizedString("Download", comment: "UpdateSettingsView")) {
                                Task {
                                    await updateManager.downloadAndInstall()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            
                            Button(NSLocalizedString("Download", comment: "UpdateSettingsView")) {
                                Task {
                                    await updateManager.downloadAndInstall()
                                }
                            }
                            .buttonStyle(.automatic)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showReleaseNotes) {
            UpdateReleaseNotesView(updateInfo: updateInfo)
        }
    }
}

struct UpdateReleaseNotesView: View {
    let updateInfo: UTMUpdateManager.UpdateInfo
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    
                    Text(NSLocalizedString("Release Notes", comment: "UpdateSettingsView"))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                
                Button(NSLocalizedString("Done", comment: "UpdateSettingsView")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.secondary.opacity(0.3)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Version header
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Text(String.localizedStringWithFormat(NSLocalizedString("UTM %@", comment: "UpdateSettingsView"), updateInfo.version))
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text(String.localizedStringWithFormat(NSLocalizedString("Released: %@", comment: "UpdateSettingsView"), updateInfo.releaseDate.abbreviatedDateString))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if updateInfo.isCritical {
                                    
                                    Label(NSLocalizedString("Critical Update", comment: "UpdateSettingsView"), systemImage: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                if updateInfo.isPrerelease {
                                    
                                    Label(NSLocalizedString("Beta", comment: "UpdateSettingsView"), systemImage: "hammer.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    MarkdownRenderer(content: updateInfo.releaseNotes)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct UpdateSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateSettingsView()
    }
}
