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

struct UpdateAvailableView: View {
    let updateInfo: UTMUpdateManager.UpdateInfo
    @ObservedObject var updateManager: UTMUpdateManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showReleaseNotes = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                
                Text(String.localizedStringWithFormat(NSLocalizedString("UTM %@ is available", comment: "UpdateAvailableView"), updateInfo.version))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                
                Text(String.localizedStringWithFormat(NSLocalizedString("Your current version is %@", comment: "UpdateAvailableView"), updateManager.currentVersion))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(String.localizedStringWithFormat(NSLocalizedString("Released %@", comment: "UpdateAvailableView"), updateInfo.releaseDate.abbreviatedDateString))
                    
                    if updateInfo.isCritical {
                        
                        Label(NSLocalizedString("Critical Update", comment: "UpdateAvailableView"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if updateInfo.isPrerelease {
                        
                        Label(NSLocalizedString("Beta", comment: "UpdateAvailableView"), systemImage: "hammer.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Release notes summary
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        
                        Text(NSLocalizedString("What's New", comment: "UpdateAvailableView"))
                            .font(.headline)
                        Spacer()
                        
                        Button(NSLocalizedString("Show Full Release Notes", comment: "UpdateAvailableView")) {
                            showReleaseNotes = true
                        }
                        .font(.caption)
                    }
                    
                    MarkdownPreview(content: updateInfo.releaseNotes, maxLength: 300)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxHeight: 150)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            if updateManager.isDownloading {
                UpdateProgressView(updateManager: updateManager)
            } else if updateManager.isInstalling {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text(NSLocalizedString("Installing Update...", comment: "UpdateAvailableView"))
                        .font(.headline)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Error display
            if let error = updateManager.updateError {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                
                Button(NSLocalizedString("Skip This Version", comment: "UpdateAvailableView")) {
                    updateManager.skipVersion(updateInfo.version)
                    presentationMode.wrappedValue.dismiss()
                }
                
                
                Button(NSLocalizedString("Remind Me Later", comment: "UpdateAvailableView")) {
                    presentationMode.wrappedValue.dismiss()
                }
                
                if updateManager.isDownloading {
                    
                    Button(NSLocalizedString("Cancel Download", comment: "UpdateAvailableView")) {
                        updateManager.cancelDownload()
                    }
                } else if !updateManager.isInstalling {
                    if #available(macOS 12.0, *) {
                        
                        Button(NSLocalizedString("Download", comment: "UpdateAvailableView")) {
                            Task {
                                await updateManager.downloadAndInstall()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(updateManager.isDownloading || updateManager.isInstalling)
                    } else {
                        
                        Button(NSLocalizedString("Download", comment: "UpdateAvailableView")) {
                            Task {
                                await updateManager.downloadAndInstall()
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(updateManager.isDownloading || updateManager.isInstalling)
                    }
                }
            }
        }
        .padding()
        .frame(width: 480, height: 520)
        .sheet(isPresented: $showReleaseNotes) {
            UpdateReleaseNotesView(updateInfo: updateInfo)
        }
    }
}

struct UpdateProgressView: View {
    @ObservedObject var updateManager: UTMUpdateManager
    
    var body: some View {
        VStack(spacing: 12) {
            if updateManager.isDownloading {
                VStack(spacing: 8) {
                    
                    Text(String.localizedStringWithFormat(NSLocalizedString("Downloading UTM %@", comment: "UpdateAvailableView"), updateManager.latestVersion))
                        .font(.headline)
                    
                    ProgressView(value: updateManager.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(Int(updateManager.downloadProgress * 100))%")
                        Spacer()
                        // download speed and time remaining could be added here if needed
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else if updateManager.isInstalling {
                VStack(spacing: 8) {
                    
                    Text(NSLocalizedString("Preparing Installation", comment: "UpdateAvailableView"))
                        .font(.headline)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    
                    Text(NSLocalizedString("Opening DMG and showing installation instructions", comment: "UpdateAvailableView"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UpdateErrorView: View {
    let error: UTMUpdateManager.UpdateError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            
            Text(NSLocalizedString("Update Failed", comment: "UpdateAvailableView"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            switch error {
            case .networkUnavailable:
                
                Text(NSLocalizedString("Please check your internet connection and try again.", comment: "UpdateAvailableView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    
            case .insufficientSpace:
                
                Text(NSLocalizedString("Free up some disk space and try again.", comment: "UpdateAvailableView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    
            case .downloadFailed, .verificationFailed:
                
                Text(NSLocalizedString("This might be a temporary issue. Please try again.", comment: "UpdateAvailableView"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    
            default:
                EmptyView()
            }
            
            HStack(spacing: 12) {
                
                Button(NSLocalizedString("Cancel", comment: "UpdateAvailableView")) {
                    onDismiss()
                }
                
                if #available(macOS 12.0, *) {
                    
                    Button(NSLocalizedString("Try Again", comment: "UpdateAvailableView")) {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    
                    Button(NSLocalizedString("Try Again", comment: "UpdateAvailableView")) {
                        onRetry()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - Previews
struct UpdateAvailableView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateAvailableView(
            updateInfo: UTMUpdateManager.UpdateInfo(
                version: "4.5.0",
                releaseDate: Date(),
                downloadURL: URL(string: "https://github.com/utmapp/UTM/releases/download/v4.5.0/UTM.dmg")!,
                releaseNotes: "## New Features\n\n* Added support for new CPU architectures\n* Improved performance\n* Bug fixes",
                fileSize: 150_000_000,
                minimumSystemVersion: "11.0",
                isCritical: false,
                isPrerelease: false,
                assets: []
            ),
            updateManager: UTMUpdateManager.shared
        )
    }
}
