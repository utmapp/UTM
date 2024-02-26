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
import QEMUKit

class UTMPipeInterface: NSObject, QEMUInterface {
    weak var connectDelegate: QEMUInterfaceConnectDelegate?

    var monitorOutPipeURL: URL!
    var monitorInPipeURL: URL!
    var guestAgentOutPipeURL: URL!
    var guestAgentInPipeURL: URL!

    private var pipeIOQueue = DispatchQueue(label: "UTMPipeInterface")
    private var qemuMonitorPort: Port!
    private var qemuGuestAgentPort: Port!

    func start() throws {
        try initializePipe(at: monitorOutPipeURL)
        try initializePipe(at: monitorInPipeURL)
        try initializePipe(at: guestAgentOutPipeURL)
        try initializePipe(at: guestAgentInPipeURL)
    }

    func connect() throws {
        pipeIOQueue.async { [self] in
            do {
                try openQemuPipes()
                connectDelegate?.qemuInterface(self, didCreateMonitorPort: qemuMonitorPort)
                connectDelegate?.qemuInterface(self, didCreateGuestAgentPort: qemuGuestAgentPort)
            } catch {
                connectDelegate?.qemuInterface(self, didErrorWithMessage: error.localizedDescription)
            }
        }
    }

    func disconnect() {
        cleanupPipes()
    }
}

extension UTMPipeInterface {
    class Port: NSObject, QEMUPort {
        let readPipe: FileHandle

        let writePipe: FileHandle

        var readDataHandler: readDataHandler_t?

        var errorHandler: errorHandler_t?

        var disconnectHandler: disconnectHandler_t?

        let isOpen: Bool = true

        init(readPipe: FileHandle, writePipe: FileHandle) {
            self.readPipe = readPipe
            self.writePipe = writePipe
            super.init()
            readPipe.readabilityHandler = { fileHandle in
                self.readDataHandler?(fileHandle.availableData)
            }
        }

        func write(_ data: Data) {
            writePipe.write(data)
        }
    }

    private var fileManager: FileManager {
        FileManager.default
    }

    private func initializePipe(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        guard mkfifo(url.path, S_IRUSR | S_IWUSR) == 0 else {
            throw ServerError.failedToCreatePipe(errno)
        }
    }

    private func openPipe(at url: URL, forReading isRead: Bool) throws -> FileHandle {
        let fileHandle: FileHandle
        if isRead {
            fileHandle = try FileHandle(forReadingFrom: url)
        } else {
            fileHandle = try FileHandle(forWritingTo: url)
        }
        return fileHandle
    }

    private func cleanupPipes() {
        // unblock any un-opened pipes
        _ = try? FileHandle(forUpdating: monitorOutPipeURL)
        _ = try? FileHandle(forUpdating: monitorInPipeURL)
        _ = try? FileHandle(forUpdating: guestAgentOutPipeURL)
        _ = try? FileHandle(forUpdating: guestAgentInPipeURL)
        pipeIOQueue.sync {
            if let monitorOutPipeURL = monitorOutPipeURL {
                try? fileManager.removeItem(at: monitorOutPipeURL)
            }
            if let monitorInPipeURL = monitorInPipeURL {
                try? fileManager.removeItem(at: monitorInPipeURL)
            }
            if let guestAgentOutPipeURL = guestAgentOutPipeURL {
                try? fileManager.removeItem(at: guestAgentOutPipeURL)
            }
            if let guestAgentInPipeURL = guestAgentInPipeURL {
                try? fileManager.removeItem(at: guestAgentInPipeURL)
            }
            qemuMonitorPort = nil
            qemuGuestAgentPort = nil
        }
    }

    private func openQemuPipes() throws {
        let qmpReadPipe = try openPipe(at: monitorOutPipeURL, forReading: true)
        let qmpWritePipe = try openPipe(at: monitorInPipeURL, forReading: false)
        qemuMonitorPort = Port(readPipe: qmpReadPipe, writePipe: qmpWritePipe)
        let qgaReadPipe = try openPipe(at: guestAgentOutPipeURL, forReading: true)
        let qgaWritePipe = try openPipe(at: guestAgentInPipeURL, forReading: false)
        qemuGuestAgentPort = Port(readPipe: qgaReadPipe, writePipe: qgaWritePipe)
    }
}

extension UTMPipeInterface {
    enum ServerError: LocalizedError {
        case failedToCreatePipe(Int32)

        var errorDescription: String? {
            switch self {
            case .failedToCreatePipe(_):
                return NSLocalizedString("Failed to create pipe for communications.", comment: "UTMPipeInterface")
            }
        }
    }
}
