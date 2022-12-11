//
// Copyright © 2022 osy. All rights reserved.
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
import Socket

/// Client logic for UTM API
actor UTMAPIClient {
    /// File URL of the Unix socket to connect to
    private(set) var connectPathUrl: URL
    
    /// The client socket when connected
    private var clientSocket: Socket?
    
    /// True if the client socket is connected
    var isConnected: Bool {
        clientSocket != nil
    }
    
    init(connectPathUrl: URL) {
        self.connectPathUrl = connectPathUrl
    }
    
    /// Establish connection to server
    func connect() async throws {
        guard clientSocket == nil else {
            return
        }
        guard FileManager.default.isReadableFile(atPath: connectPathUrl.path) else {
            throw UTMAPI.APIError.serverNotFound
        }
        let address = UnixSocketAddress(path: FilePath(connectPathUrl.path))
        let socket = try await Socket(UnixStreamProtocol.stream)
        do {
            try socket.fileDescriptor.closeIfThrows {
                try socket.fileDescriptor.connect(to: address)
            }
        } catch Errno.connectionRefused {
            throw UTMAPI.APIError.serverNotFound
        }
        logger.debug("[API Client] connected to server")
        clientSocket = socket
    }
    
    /// Terminate connection to server
    func disconnect() async throws {
        guard let clientSocket = clientSocket else {
            return
        }
        self.clientSocket = nil
        await clientSocket.close()
    }
    
    /// Send a request to the server and wait for the response
    /// - Parameter request: Request to server
    /// - Returns: Response from server
    func process<Request: UTMAPIRequest>(request: Request) async throws -> Request.Response {
        guard let clientSocket = clientSocket else {
            throw UTMAPI.APIError.notConnected
        }
        try await sendRequest(request, to: clientSocket)
        logger.debug("[API Client] waiting for response length")
        let length = try await clientSocket.read(4).withUnsafeBytes { body in
            body.load(as: UInt32.self)
        }
        logger.debug("[API Client] response length = \(length)")
        let data = try await clientSocket.read(Int(length))
        logger.debug("[API Client] got response: \(String(data: data, encoding: .utf8) ?? "(failed to decode)")")
        let response = try UTMAPI.decodeResponse(from: data)
        logger.debug("[API Client] decoded response: \(response)")
        guard let response = response as? Request.Response else {
            if let response = response as? UTMAPI.ErrorResponse {
                throw UTMAPI.APIError.errorResponse(description: response.error)
            } else {
                throw UTMAPI.APIError.responseFormatMismatch
            }
        }
        return response
    }
    
    /// Sends the request to the server
    /// - Parameters:
    ///   - request: Request to send
    ///   - socket: Server to send request to
    private nonisolated func sendRequest(_ request: any UTMAPIRequest, to socket: Socket) async throws {
        let requestJson = try UTMAPI.encode(request)
        var requestLength = UInt32(requestJson.count)
        logger.debug("[API Client] Sending request (len: \(requestLength)): \(String(data: requestJson, encoding: .utf8) ?? "(failed to decode)")")
        try await socket.write(Data(bytes: &requestLength, count: MemoryLayout.size(ofValue: requestLength)))
        try await socket.write(requestJson)
    }
}
