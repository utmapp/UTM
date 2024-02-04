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

final class UTMRemoteSpiceVirtualMachine: UTMSpiceVirtualMachine {
    struct Capabilities: UTMVirtualMachineCapabilities {
        var supportsProcessKill: Bool {
            true
        }

        var supportsSnapshots: Bool {
            true
        }

        var supportsScreenshots: Bool {
            true
        }

        var supportsDisposibleMode: Bool {
            true
        }

        var supportsRecoveryMode: Bool {
            false
        }

        var supportsRemoteSession: Bool {
            false
        }
    }

    static let capabilities = Capabilities()

    private let server: UTMRemoteClient.Remote

    init(packageUrl: URL, configuration: UTMQemuConfiguration, isShortcut: Bool) throws {
        throw UTMVirtualMachineError.notImplemented
    }

    init(forRemoteServer server: UTMRemoteClient.Remote, remotePath: String, entry: UTMRegistryEntry, config: UTMQemuConfiguration) {
        self.pathUrl = URL(fileURLWithPath: remotePath)
        self.config = config
        self.registryEntry = entry
        self.server = server
    }

    private(set) var pathUrl: URL

    private(set) var isShortcut: Bool = false

    private(set) var isRunningAsDisposible: Bool = false

    var delegate: (UTMVirtualMachineDelegate)?
    
    var onConfigurationChange: (() -> Void)?
    
    var onStateChange: (() -> Void)?

    private(set) var config: UTMQemuConfiguration

    private(set) var registryEntry: UTMRegistryEntry

    private(set) var state: UTMVirtualMachineState = .stopped

    var screenshot: PlatformImage?

    private(set) var snapshotUnsupportedError: Error?

    weak var ioServiceDelegate: UTMSpiceIODelegate? {
        didSet {
            if let ioService = ioService {
                ioService.delegate = ioServiceDelegate
            }
        }
    }

    private(set) var ioService: UTMSpiceIO? {
        didSet {
            oldValue?.delegate = nil
            ioService?.delegate = ioServiceDelegate
        }
    }

    var changeCursorRequestInProgress: Bool = false

    func reload(from packageUrl: URL?) throws {

    }
    
    func updateConfigFromRegistry() {

    }
    
    func changeUuid(to uuid: UUID, name: String?, copyingEntry entry: UTMRegistryEntry?) {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    func start(options: UTMVirtualMachineStartOptions) async throws {

    }

    func stop(usingMethod method: UTMVirtualMachineStopMethod) async throws {

    }

    func restart() async throws {

    }

    func pause() async throws {

    }

    func resume() async throws {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    func requestInputTablet(_ tablet: Bool) {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    func eject(_ drive: UTMQemuConfigurationDrive) async throws {

    }

    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {

    }

}

extension UTMRemoteSpiceVirtualMachine {
    func stopAccessingPath(_ path: String) async {

    }

    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {

    }
}

extension UTMRemoteSpiceVirtualMachine {
    enum VMError: LocalizedError {
    }
}
