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

/// Server logic for UTM API
actor UTMAPIServer {
    /// Delegate to handle client requests
    public weak var delegate: UTMAPIDelegate?
    
    /// File URL of the Unix socket to listen on
    private(set) var listenPathUrl: URL
    
    /// The server Task when started
    private var serverTask: Task<Void, Error>?
    
    /// Returns the status of the server
    public var isStarted: Bool {
        serverTask != nil
    }
    
    /// Keep track of connected clients in order to terminate them all if requested
    private actor ClientStore {
        private var clients = Set<SocketDescriptor>()
        
        /// Add a new client to the store
        /// - Parameter newMember: The new client
        func insert(_ newMember: SocketDescriptor) {
            clients.insert(newMember)
        }
        
        /// Remove an existing client from the store
        /// - Parameter member: The existing client
        func remove(_ member: SocketDescriptor) {
            clients.remove(member)
        }
        
        /// Close all clients referenced in the store
        func closeAll() {
            clients.forEach { socketDescriptor in
                do {
                    try socketDescriptor.close()
                } catch {
                    logger.debug("[API Server] Error closing socket \(socketDescriptor.rawValue): \(error)")
                }
            }
        }
    }
    
    init(listenPathUrl: URL, delegate: UTMAPIDelegate?) {
        self.listenPathUrl = listenPathUrl
        self.delegate = delegate
    }
    
    /// Start the API server
    func start() async throws {
        guard serverTask == nil else {
            return
        }
        let address = UnixSocketAddress(path: FilePath(listenPathUrl.path))
        let socket = try await Socket(UnixStreamProtocol.stream)
        let option: GenericSocketOption.ReuseAddress = true
        try socket.fileDescriptor.closeIfThrows {
            try socket.fileDescriptor.setSocketOption(option)
            unlink(address.path.string)
            try socket.fileDescriptor.bind(address)
        }
        
        logger.info("[API Server] started on \(address.path) (\(socket.fileDescriptor.rawValue))")
        serverTask = Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { taskGroup in
                do {
                    try await self.serverLoop(on: socket, taskGroup: &taskGroup)
                } catch {
                    logger.error("[API Server] Server error: \(error)")
                }
            }
            await socket.close()
            logger.info("[API Server] stopped.")
        }
    }
    
    /// Stop the API server
    ///
    /// This will close all clients and close the server.
    /// The function will return when the server task terminates.
    func stop() {
        guard let serverTask = serverTask else {
            return
        }
        self.serverTask = nil
        serverTask.cancel()
    }
    
    /// Main loop handling server logic
    ///
    /// This should be run in a new Task.
    /// - Parameters:
    ///   - socket: Server socket to listen on
    ///   - taskGroup: Task group to add new client tasks
    private nonisolated func serverLoop(on socket: Socket, taskGroup: inout TaskGroup<Void>) async throws {
        let clientStore = ClientStore()
        try socket.fileDescriptor.listen(backlog: 128)
        repeat {
            let client = await Socket(fileDescriptor: try await socket.fileDescriptor.accept())
            logger.info("[API Server] New client connected: \(client.fileDescriptor.rawValue).")
            await clientStore.insert(client.fileDescriptor)
            _ = taskGroup.addTaskUnlessCancelled {
                do {
                    try await self.clientHandleLoop(on: client)
                } catch {
                    logger.error("[API Server] Client \(client.fileDescriptor.rawValue) error: \(error)")
                }
                await client.close()
                logger.info("[API Server] Client \(client.fileDescriptor.rawValue) closed")
                await clientStore.remove(client.fileDescriptor)
            }
        } while !Task.isCancelled
        await clientStore.closeAll()
    }
    
    /// Main loop handling client requests
    ///
    /// Each client should run this in its own Task.
    /// - Parameter socket: Client socket to handle.
    private nonisolated func clientHandleLoop(on socket: Socket) async throws {
        repeat {
            try await clientHandleRequest(on: socket)
        } while !Task.isCancelled
    }
    
    /// Handle a single client request
    /// - Parameter socket: Client socket to handle.
    private nonisolated func clientHandleRequest(on socket: Socket) async throws {
        let id = socket.fileDescriptor.rawValue
        logger.debug("[API Server] Client \(id) waiting for next request...")
        let length = try await socket.read(4).withUnsafeBytes { body in
            body.load(as: UInt32.self)
        }
        logger.debug("[API Server] Client \(id) will read \(length) bytes")
        let data = try await socket.read(Int(length))
        logger.debug("[API Server] Client \(id) got new request: \(String(data: data, encoding: .utf8) ?? "(failed to decode)")")
        var command = UTMAPI.Command.error
        var response: any UTMAPIResponse
        do {
            let request = try UTMAPI.decodeRequest(from: data)
            command = request.command
            logger.debug("[API Server] Decoded request: \(request)")
            guard let delegate = await delegate else {
                throw UTMAPI.APIError.handlerNotFound
            }
            response = try await delegate.handleAPIRequest(request)
        } catch {
            logger.debug("[API Server] Client \(id) error handling command '\(command)': \(error)")
            response = UTMAPI.ErrorResponse(error.localizedDescription)
        }
        guard !Task.isCancelled else {
            return
        }
        try await sendResponse(response, to: socket)
    }
    
    /// Sends the response to the client
    /// - Parameters:
    ///   - response: Response to send
    ///   - socket: Client to send response to
    private nonisolated func sendResponse(_ response: any UTMAPIResponse, to socket: Socket) async throws {
        let id = socket.fileDescriptor.rawValue
        let responseJson = try UTMAPI.encode(response)
        var responseLength = UInt32(responseJson.count)
        logger.debug("[API Server] Client \(id) sending response (len: \(responseLength)): \(String(data: responseJson, encoding: .utf8) ?? "(failed to decode)")")
        try await socket.write(Data(bytes: &responseLength, count: MemoryLayout.size(ofValue: responseLength)))
        try await socket.write(responseJson)
    }
}
