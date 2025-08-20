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
import Combine

@MainActor
class UTMDownloadManager: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadSpeed: String = ""
    @Published var estimatedTimeRemaining: String = ""
    @Published var isDownloading: Bool = false
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadedFileURL: URL?
    private var expectedContentLength: Int64 = 0
    private var bytesReceived: Int64 = 0
    private var startTime: Date?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.utmapp.UTM.update-download")
        config.allowsCellularAccess = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = false
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    func downloadUpdate(from url: URL) async throws -> URL {
        guard !isDownloading else {
            throw UTMUpdateManager.UpdateError.downloadFailed("Download already in progress")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            startDownload(from: url) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func startDownload(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isDownloading else {
            completion(.failure(UTMUpdateManager.UpdateError.downloadFailed("Download already in progress")))
            return
        }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.bytesReceived = 0
            self.startTime = Date()
        }
        
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
        
        // Store completion handler
        downloadCompletion = completion
    }
    
    private var downloadCompletion: ((Result<URL, Error>) -> Void)?
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        
        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadProgress = 0.0
            self.downloadSpeed = ""
            self.estimatedTimeRemaining = ""
        }
        
        downloadCompletion?(.failure(UTMUpdateManager.UpdateError.downloadFailed("Download cancelled")))
        downloadCompletion = nil
    }
    
    func cleanupDownload() {
        if let downloadedFileURL = downloadedFileURL {
            try? FileManager.default.removeItem(at: downloadedFileURL)
            self.downloadedFileURL = nil
        }
    }
    
    private func formatByteSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return "\(Int(timeInterval))s"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func updateProgress() {
        guard expectedContentLength > 0 else { return }
        
        let progress = Double(bytesReceived) / Double(expectedContentLength)
        let elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        
        DispatchQueue.main.async {
            self.downloadProgress = progress
            
            if elapsedTime > 0 {
                let speed = Double(self.bytesReceived) / elapsedTime
                self.downloadSpeed = self.formatByteSpeed(speed)
                
                if speed > 0 {
                    let remainingBytes = self.expectedContentLength - self.bytesReceived
                    let remainingTime = Double(remainingBytes) / speed
                    self.estimatedTimeRemaining = self.formatTimeInterval(remainingTime)
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension UTMDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move file to a permanent location
        let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("UTMUpdate-\(UUID().uuidString).dmg")
        
        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            Task { @MainActor in
                self.downloadedFileURL = destinationURL
                self.isDownloading = false
                self.downloadCompletion?(.success(destinationURL))
                self.downloadCompletion = nil
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.downloadCompletion?(.failure(UTMUpdateManager.UpdateError.downloadFailed(error.localizedDescription)))
                self.downloadCompletion = nil
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            self.expectedContentLength = totalBytesExpectedToWrite
            self.bytesReceived = totalBytesWritten
            self.updateProgress()
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isDownloading = false
                self.downloadCompletion?(.failure(UTMUpdateManager.UpdateError.downloadFailed(error.localizedDescription)))
                self.downloadCompletion = nil
            }
        }
    }
}
