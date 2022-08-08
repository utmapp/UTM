//
// Copyright © 2021 osy. All rights reserved.
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

/// A Virtual Machine that has not finished downloading.
@MainActor class UTMPendingVirtualMachine: Equatable, Identifiable, ObservableObject {
    internal init(name: String, onCancel: @escaping () -> ()) {
        self.name = name
        self.cancel = onCancel
        dateFormatter = DateComponentsFormatter()
        dateFormatter.allowedUnits = [.second, .minute, .hour]
        dateFormatter.unitsStyle = .abbreviated
    }
    
    #if DEBUG
    /// init for SwiftUI Preview
    internal init(name: String) {
        dateFormatter = DateComponentsFormatter()
        dateFormatter.allowedUnits = [.second, .minute, .hour]
        dateFormatter.unitsStyle = .abbreviated
        self.name = name
        self.downloadProgress = 0.41
        self.cancel = {}
    }
    #endif
    
    let downloadStart = Date()
    private let dateFormatter: DateComponentsFormatter
    private var lastETAUpdate = Date()
    private var lastDownloadSpeedUpdate = Date()
    private var bytesWrittenSinceLastDownloadSpeedUpdate: Int64 = 0
    nonisolated private let uuid = UUID()
    let name: String
    let cancel: () -> ()
    
    // TODO: Refactor to avoid non-optional optionals.
    // There should be a state enum or something to represent the steps of the pending VM progress
    @Published private(set) var downloadedSize: String? = nil
    @Published private(set) var estimatedDownloadSize: String? = nil
    /// if `nil`, either the download has not started or has finished and it is currently extracting.
    /// Can not cancel if currently extracting.
    @Published private(set) var estimatedDownloadSpeed: String? = nil
    @Published private(set) var downloadProgress: CGFloat = 0
    @Published private(set) var estimatedTimeRemaining: String? = nil
    
    nonisolated static func == (lhs: UTMPendingVirtualMachine, rhs: UTMPendingVirtualMachine) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    nonisolated var id: UUID {
        uuid
    }
    
    private func updateETAStringIfNeeded(_ progress: Float) {
        /// only update the ETA string every full second, otherwise the UI is too busy
        guard lastETAUpdate.timeIntervalSinceNow < -1 else {
            return
        }
        if progress > 0.999 {
            estimatedTimeRemaining = nil
            return
        }
        lastETAUpdate = Date()
        let elapsed = Float(-downloadStart.timeIntervalSinceNow)
        let estimatedTotalTime = elapsed / progress
        let estimatedTimeRemaining = estimatedTotalTime - elapsed
        let secondsRemaining = TimeInterval(estimatedTimeRemaining).rounded()
        guard let etaString = dateFormatter.string(from: secondsRemaining) else {
            self.estimatedTimeRemaining = nil
            return
        }
        let localizedFormatString = NSLocalizedString("%@ remaining", comment: "Format string for remaining time until a download finishes")
        self.estimatedTimeRemaining = String.localizedStringWithFormat(localizedFormatString, etaString)
    }
    
    private func updateDownloadStats(for newBytesWritten: Int64, currentTotal totalBytesWritten: Int64, estimatedTotal totalBytesExpectedToWrite: Int64) {
        bytesWrittenSinceLastDownloadSpeedUpdate += newBytesWritten
        /// only update the download speed string every full second, otherwise the UI is too busy
        let elapsed = -lastDownloadSpeedUpdate.timeIntervalSinceNow
        guard elapsed > 1 else {
            return
        }
        lastDownloadSpeedUpdate = Date()
        let bytesPerSecond = bytesWrittenSinceLastDownloadSpeedUpdate
        bytesWrittenSinceLastDownloadSpeedUpdate = 0
        let bytesString = ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .file)
        let speedFormat = NSLocalizedString("%@ / s",
                                            comment: "Format string for the 'per second' part of a download speed.")
        estimatedDownloadSpeed = String.localizedStringWithFormat(speedFormat, bytesString)
        /// sizes
        downloadedSize = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
        estimatedDownloadSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
    }
    
    public func setDownloadProgress(new newBytesWritten: Int64, currentTotal totalBytesWritten: Int64, estimatedTotal totalBytesExpectedToWrite: Int64) {
        objectWillChange.send()
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        downloadProgress = CGFloat(progress)
        updateETAStringIfNeeded(progress)
        updateDownloadStats(for: newBytesWritten, currentTotal: totalBytesWritten, estimatedTotal: totalBytesExpectedToWrite)
    }
    
    func resetProgress(to progress: CGFloat) {
        objectWillChange.send()
        downloadProgress = progress
        downloadedSize = estimatedDownloadSize
        estimatedDownloadSpeed = nil
        estimatedTimeRemaining = nil
    }
    
    public func setDownloadStarting() {
        resetProgress(to: 0)
    }
    
    public func setDownloadFinishedNowProcessing() {
        resetProgress(to: 1)
    }
}
