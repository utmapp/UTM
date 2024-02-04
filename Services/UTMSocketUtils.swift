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

import Darwin

struct UTMSocketUtils {
    /// Reserve an ephemeral port from the system
    ///
    /// First we `bind` to port 0 in order to allocate an ephemeral port.
    /// Next, we `connect` to that port to establish a connection.
    /// Finally, we close the port and put it into the `TIME_WAIT` state.
    ///
    /// This allows another process to `bind` the port with `SO_REUSEADDR` specified.
    /// However, for the next ~120 seconds, the system will not re-use this port.
    /// - Returns: A port number that is valid for ~120 seconds.
    static func reservePort() throws -> UInt16 {
        let serverSock = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSock >= 0 else {
            throw SocketError.cannotReservePort(errno)
        }
        defer {
            close(serverSock)
        }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY
        addr.sin_port = 0 // request an ephemeral port

        var len = socklen_t(MemoryLayout<sockaddr_in>.stride)
        let res = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                let res1 = bind(serverSock, $0, len)
                let res2 = getsockname(serverSock, $0, &len)
                return (res1, res2)
            }
        }
        guard res.0 == 0 && res.1 == 0 else {
            throw SocketError.cannotReservePort(errno)
        }

        guard listen(serverSock, 1) == 0 else {
            throw SocketError.cannotReservePort(errno)
        }

        let clientSock = socket(AF_INET, SOCK_STREAM, 0)
        guard clientSock >= 0 else {
            throw SocketError.cannotReservePort(errno)
        }
        defer {
            close(clientSock)
        }
        let res3 = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(clientSock, $0, len)
            }
        }
        guard res3 == 0 else {
            throw SocketError.cannotReservePort(errno)
        }

        let acceptSock = accept(serverSock, nil, nil)
        guard acceptSock >= 0 else {
            throw SocketError.cannotReservePort(errno)
        }
        defer {
            close(acceptSock)
        }
        return addr.sin_port.byteSwapped
    }
}

extension UTMSocketUtils {
    enum SocketError: LocalizedError {
        case cannotReservePort(Int32)

        var errorDescription: String? {
            switch self {
            case .cannotReservePort(_):
                return NSLocalizedString("Cannot reserve an unused port on this system.", comment: "UTMSocketUtils")
            }
        }
    }
}
