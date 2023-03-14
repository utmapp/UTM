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

@MainActor
@objc(UTMScriptingGuestFileImpl)
class UTMScriptingGuestFileImpl: NSObject, UTMScriptable {
    @objc private(set) var id: Int
    
    weak private var parent: UTMScriptingVirtualMachineImpl?
    weak private var guestAgent: UTMQemuGuestAgent?
    
    init(from handle: Int, parent: UTMScriptingVirtualMachineImpl) {
        self.id = handle
        self.parent = parent
        self.guestAgent = parent.guestAgent
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let parent = parent else {
            return nil
        }
        guard let parentDescription = parent.classDescription as? NSScriptClassDescription else {
            return nil
        }
        let parentSpecifier = parent.objectSpecifier
        return NSUniqueIDSpecifier(containerClassDescription: parentDescription,
                                   containerSpecifier: parentSpecifier,
                                   key: "openFiles",
                                   uniqueID: id)
    }
    
    private func seek(to offset: Int, whence: AEKeyword?, using guestAgent: UTMQemuGuestAgent) async throws {
        let seek: QGASeek
        if let whence = whence {
            switch UTMScriptingWhence(rawValue: whence) {
            case .startPosition: seek = QGA_SEEK_SET
            case .currentPosition: seek = QGA_SEEK_CUR
            case .endPosition: seek = QGA_SEEK_END
            default: seek = QGA_SEEK_SET
            }
        } else {
            seek = QGA_SEEK_SET
        }
        try await guestAgent.guestFileSeek(id, offset: offset, whence: seek)
    }
    
    @objc func read(_ command: NSScriptCommand) {
        let id = self.id
        let offset = command.evaluatedArguments?["offset"] as? Int
        let whence = command.evaluatedArguments?["whence"] as? AEKeyword
        let length = command.evaluatedArguments?["length"] as? Int
        let isBase64Encoded = command.evaluatedArguments?["isBase64Encoded"] as? Bool ?? false
        let isClosing = command.evaluatedArguments?["isClosing"] as? Bool ?? true
        withScriptCommand(command) { [self] in
            guard let guestAgent = guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            defer {
                if isClosing {
                    guestAgent.guestFileClose(id)
                }
            }
            if let offset = offset {
                try await seek(to: offset, whence: whence, using: guestAgent)
            }
            if let length = length {
                let data = try await guestAgent.guestFileRead(id, count: length)
                return textFromData(data, isBase64Encoded: isBase64Encoded)
            }
            var data: Data
            var allData = Data()
            repeat {
                data = try await guestAgent.guestFileRead(id, count: 4096)
                allData += data
            } while data.count > 0
            return textFromData(allData, isBase64Encoded: isBase64Encoded)
        }
    }
    
    @objc func pull(_ command: NSScriptCommand) {
        let id = self.id
        let file = command.evaluatedArguments?["file"] as? URL
        let isClosing = command.evaluatedArguments?["isClosing"] as? Bool ?? true
        withScriptCommand(command) { [self] in
            guard let guestAgent = guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            defer {
                if isClosing {
                    guestAgent.guestFileClose(id)
                }
            }
            guard let file = file else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.invalidParameter
            }
            try await guestAgent.guestFileSeek(id, offset: 0, whence: QGA_SEEK_SET)
            _ = file.startAccessingSecurityScopedResource()
            defer {
                file.stopAccessingSecurityScopedResource()
            }
            let handle = try FileHandle(forWritingTo: file)
            var data: Data
            repeat {
                data = try await guestAgent.guestFileRead(id, count: 4096)
                try handle.write(contentsOf: data)
            } while data.count > 0
            try await guestAgent.guestFileClose(id)
        }
    }
    
    @objc func write(_ command: NSScriptCommand) {
        let id = self.id
        let data = command.evaluatedArguments?["data"] as? String
        let offset = command.evaluatedArguments?["offset"] as? Int
        let whence = command.evaluatedArguments?["whence"] as? AEKeyword
        let isBase64Encoded = command.evaluatedArguments?["isBase64Encoded"] as? Bool ?? false
        let isClosing = command.evaluatedArguments?["isClosing"] as? Bool ?? true
        withScriptCommand(command) { [self] in
            guard let guestAgent = guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            defer {
                if isClosing {
                    guestAgent.guestFileClose(id)
                }
            }
            guard let data = dataFromText(data, isBase64Encoded: isBase64Encoded) else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.invalidParameter
            }
            if let offset = offset {
                try await seek(to: offset, whence: whence, using: guestAgent)
            }
            try await guestAgent.guestFileWrite(id, data: data)
            try await guestAgent.guestFileFlush(id)
        }
    }
    
    @objc func push(_ command: NSScriptCommand) {
        let id = self.id
        let file = command.evaluatedArguments?["file"] as? URL
        let isClosing = command.evaluatedArguments?["isClosing"] as? Bool ?? true
        withScriptCommand(command) { [self] in
            guard let guestAgent = guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            defer {
                if isClosing {
                    guestAgent.guestFileClose(id)
                }
            }
            guard let file = file else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.invalidParameter
            }
            try await guestAgent.guestFileSeek(id, offset: 0, whence: QGA_SEEK_SET)
            _ = file.startAccessingSecurityScopedResource()
            defer {
                file.stopAccessingSecurityScopedResource()
            }
            let handle = try FileHandle(forReadingFrom: file)
            var data: Data
            repeat {
                data = try handle.read(upToCount: 4096) ?? Data()
                try await guestAgent.guestFileWrite(id, data: data)
            } while data.count > 0
        }
    }
    
    @objc func close(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            guard let guestAgent = guestAgent else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.guestAgentNotRunning
            }
            try await guestAgent.guestFileClose(id)
        }
    }
}
