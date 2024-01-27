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
}


enum UTMRemoteMessageClient: UInt8, MessageID {
    static let version = 1
    case clientHandshake
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
