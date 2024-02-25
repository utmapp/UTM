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
import SwiftConnect

enum UTMRemoteMessageServer: UInt8, MessageID {
    static let version = 1
    case serverHandshake
    case listVirtualMachines
    case reorderVirtualMachines
    case getVirtualMachineInformation
    case getQEMUConfiguration
    case getPackageSize
    case getPackageFile
    case sendPackageFile
    case deletePackageFile
    case mountGuestToolsOnVirtualMachine
    case startVirtualMachine
    case stopVirtualMachine
    case restartVirtualMachine
    case pauseVirtualMachine
    case resumeVirtualMachine
    case saveSnapshotVirtualMachine
    case deleteSnapshotVirtualMachine
    case restoreSnapshotVirtualMachine
    case changePointerTypeVirtualMachine
}


enum UTMRemoteMessageClient: UInt8, MessageID {
    static let version = 1
    case clientHandshake
    case listHasChanged
    case qemuConfigurationHasChanged
    case mountedDrivesHasChanged
    case virtualMachineDidTransition
    case virtualMachineDidError
}

extension UTMRemoteMessageServer {
    struct ServerHandshake: Message {
        static let id = UTMRemoteMessageServer.serverHandshake

        struct Request: Serializable, Codable {
            let version: Int
            let password: String?
        }

        struct Reply: Serializable, Codable {
            let version: Int
            let isAuthenticated: Bool
            let capabilities: UTMCapabilities
            let model: String
        }
    }

    struct VirtualMachineInformation: Serializable, Codable {
        let id: UUID
        let name: String
        let path: String
        let isShortcut: Bool
        let isSuspended: Bool
        let isTakeoverAllowed: Bool
        let backend: UTMBackend
        let state: UTMVirtualMachineState
        let mountedDrives: [String: String]
    }

    struct ListVirtualMachines: Message {
        static let id = UTMRemoteMessageServer.listVirtualMachines

        struct Request: Serializable, Codable {}

        struct Reply: Serializable, Codable {
            let ids: [UUID]
        }
    }

    struct ReorderVirtualMachines: Message {
        static let id = UTMRemoteMessageServer.reorderVirtualMachines

        struct Request: Serializable, Codable {
            let ids: [UUID]
            let offset: Int
        }

        struct Reply: Serializable, Codable {}
    }

    struct GetVirtualMachineInformation: Message {
        static let id = UTMRemoteMessageServer.getVirtualMachineInformation

        struct Request: Serializable, Codable {
            let ids: [UUID]
        }

        struct Reply: Serializable, Codable {
            let informations: [VirtualMachineInformation]
        }
    }

    struct GetQEMUConfiguration: Message {
        static let id = UTMRemoteMessageServer.getQEMUConfiguration

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {
            let configuration: UTMQemuConfiguration
        }
    }

    struct GetPackageSize: Message {
        static let id = UTMRemoteMessageServer.getPackageSize

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {
            let size: Int64
        }
    }

    struct GetPackageFile: Message {
        static let id = UTMRemoteMessageServer.getPackageFile

        struct Request: Serializable, Codable {
            let id: UUID
            let relativePathComponents: [String]
            let lastModified: Date?
        }

        struct Reply: Serializable, Codable {
            let data: Data?
            let lastModified: Date
        }
    }

    struct SendPackageFile: Message {
        static let id = UTMRemoteMessageServer.sendPackageFile

        struct Request: Serializable, Codable {
            let id: UUID
            let relativePathComponents: [String]
            let lastModified: Date
            let data: Data
        }

        struct Reply: Serializable, Codable {}
    }

    struct DeletePackageFile: Message {
        static let id = UTMRemoteMessageServer.deletePackageFile

        struct Request: Serializable, Codable {
            let id: UUID
            let relativePathComponents: [String]
        }

        struct Reply: Serializable, Codable {}
    }

    struct MountGuestToolsOnVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.mountGuestToolsOnVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {}
    }

    struct StartVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.startVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let options: UTMVirtualMachineStartOptions
        }

        struct ServerInformation: Serializable, Codable {
            let spicePortInternal: UInt16
            let spicePortExternal: UInt16?
            let spiceHostExternal: String?
            let spicePublicKey: Data
            let spicePassword: String
        }

        struct Reply: Serializable, Codable {
            let serverInfo: ServerInformation
        }
    }

    struct StopVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.stopVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let method: UTMVirtualMachineStopMethod
        }

        struct Reply: Serializable, Codable {}
    }

    struct RestartVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.restartVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {}
    }

    struct PauseVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.pauseVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {}
    }

    struct ResumeVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.resumeVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
        }

        struct Reply: Serializable, Codable {}
    }

    struct SaveSnapshotVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.saveSnapshotVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let name: String?
        }

        struct Reply: Serializable, Codable {}
    }

    struct DeleteSnapshotVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.deleteSnapshotVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let name: String?
        }

        struct Reply: Serializable, Codable {}
    }

    struct RestoreSnapshotVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.restoreSnapshotVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let name: String?
        }

        struct Reply: Serializable, Codable {}
    }

    struct ChangePointerTypeVirtualMachine: Message {
        static let id = UTMRemoteMessageServer.changePointerTypeVirtualMachine

        struct Request: Serializable, Codable {
            let id: UUID
            let isTabletMode: Bool
        }

        struct Reply: Serializable, Codable {}
    }
}

extension Serializable where Self == UTMRemoteMessageServer.GetQEMUConfiguration.Reply {
    static func decode(_ data: Data) throws -> Self {
        let decoder = Decoder()
        decoder.userInfo[.dataURL] = URL(fileURLWithPath: "/")
        return try decoder.decode(Self.self, from: data)
    }
}

extension Serializable where Self == UTMRemoteMessageClient.QEMUConfigurationHasChanged.Request {
    static func decode(_ data: Data) throws -> Self {
        let decoder = Decoder()
        decoder.userInfo[.dataURL] = URL(fileURLWithPath: "/")
        return try decoder.decode(Self.self, from: data)
    }
}

extension UTMRemoteMessageClient {
    struct ClientHandshake: Message {
        static let id = UTMRemoteMessageClient.clientHandshake

        struct Request: Serializable, Codable {
            let version: Int
        }

        struct Reply: Serializable, Codable {
            let version: Int
            let capabilities: UTMCapabilities
        }
    }

    struct ListHasChanged: Message {
        static let id = UTMRemoteMessageClient.listHasChanged

        struct Request: Serializable, Codable {
            let ids: [UUID]
        }

        struct Reply: Serializable, Codable {}
    }

    struct QEMUConfigurationHasChanged: Message {
        static let id = UTMRemoteMessageClient.qemuConfigurationHasChanged

        struct Request: Serializable, Codable {
            let id: UUID
            let configuration: UTMQemuConfiguration
        }

        struct Reply: Serializable, Codable {}
    }

    struct MountedDrivesHasChanged: Message {
        static let id = UTMRemoteMessageClient.mountedDrivesHasChanged

        struct Request: Serializable, Codable {
            let id: UUID
            let mountedDrives: [String: String]
        }

        struct Reply: Serializable, Codable {}
    }

    struct VirtualMachineDidTransition: Message {
        static let id = UTMRemoteMessageClient.virtualMachineDidTransition

        struct Request: Serializable, Codable {
            let id: UUID
            let state: UTMVirtualMachineState
            let isTakeoverAllowed: Bool
        }

        struct Reply: Serializable, Codable {}
    }

    struct VirtualMachineDidError: Message {
        static let id = UTMRemoteMessageClient.virtualMachineDidError

        struct Request: Serializable, Codable {
            let id: UUID
            let errorMessage: String
        }

        struct Reply: Serializable, Codable {}
    }
}
