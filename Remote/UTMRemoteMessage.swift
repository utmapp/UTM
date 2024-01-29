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
    case getQEMUConfiguration
    case updateQEMUConfiguration
    case getPackageFile
}


enum UTMRemoteMessageClient: UInt8, MessageID {
    static let version = 1
    case clientHandshake
    case listHasChangedOrder
    case QEMUConfigurationHasChanged
    case packageFileHasChanged
}

extension UTMRemoteMessageServer {
    struct ServerHandshake: Message {
        static let id = UTMRemoteMessageServer.serverHandshake

        struct Request: Serializable, Codable {
            let version: Int
        }

        struct Reply: Serializable, Codable {
            let version: Int
        }
    }

    struct ListVirtualMachines: Message {
        static let id = UTMRemoteMessageServer.listVirtualMachines

        struct Request: Serializable, Codable {}

        struct Information: Serializable, Codable {
            let id: UUID
            let name: String
            let path: String
            let isShortcut: Bool
            let isSuspended: Bool
            let backend: UTMBackend
        }

        struct Reply: Serializable, Codable {
            let items: [Information]
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

    struct UpdateQEMUConfiguration: Message {
        static let id = UTMRemoteMessageServer.updateQEMUConfiguration

        struct Request: Serializable, Codable {
            let id: UUID
            let configuration: UTMQemuConfiguration
            let files: [String: Data]
        }

        struct Reply: Serializable, Codable {}
    }

    struct GetPackageFile: Message {
        static let id = UTMRemoteMessageServer.getPackageFile

        struct Request: Serializable, Codable {
            let id: UUID
            let path: String
            let existingCrc: Int32?
        }

        struct Reply: Serializable, Codable {
            let data: Data?
        }
    }
}

extension Serializable where Self == UTMRemoteMessageServer.GetQEMUConfiguration.Reply {
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
        }
    }
}
