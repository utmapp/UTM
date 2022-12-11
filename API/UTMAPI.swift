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

/// API interface encoding and decoding for UTM
final class UTMAPI {
    static func encode(_ value: any Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
    
    static func decodeRequest(from data: Data) throws -> any UTMAPIRequest {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let request = try decoder.decode(AnyRequest.self, from: data)
        switch request.command {
        case .list:
            return try decoder.decode(ListRequest.self, from: data)
        case .status:
            return try decoder.decode(StatusRequest.self, from: data)
        case .start:
            return try decoder.decode(StartRequest.self, from: data)
        case .suspend:
            return try decoder.decode(SuspendRequest.self, from: data)
        case .stop:
            return try decoder.decode(StopRequest.self, from: data)
        case .serial:
            return try decoder.decode(SerialRequest.self, from: data)
        case .error:
            throw APIError.invalidCommand
        }
    }
    
    static func decodeResponse(from data: Data) throws -> any UTMAPIResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(AnyResponse.self, from: data)
        switch response.command {
        case .list:
            return try decoder.decode(ListResponse.self, from: data)
        case .status:
            return try decoder.decode(StatusResponse.self, from: data)
        case .start:
            return try decoder.decode(StartResponse.self, from: data)
        case .suspend:
            return try decoder.decode(SuspendResponse.self, from: data)
        case .stop:
            return try decoder.decode(StopResponse.self, from: data)
        case .serial:
            return try decoder.decode(SerialResponse.self, from: data)
        case .error:
            return try decoder.decode(ErrorResponse.self, from: data)
        }
    }
}

extension UTMAPI {
    /// List of supported commands
    enum Command: String, Codable {
        case error
        case list
        case status
        case start
        case suspend
        case stop
        case serial
    }
    
    /// Current status of a VM
    enum VMStatus: String, Codable {
        case unknown
        case stopped
        case busy
        case started
        case paused
    }
    
    /// Error codes
    enum APIError: Error {
        case notConnected
        case invalidCommand
        case handlerNotFound
        case errorResponse(description: String)
        case requestFormatMismatch
        case responseFormatMismatch
        
        var localizedDescription: String {
            switch self {
            case .notConnected: return "Not connected to API server."
            case .invalidCommand: return "Invalid command."
            case .handlerNotFound: return "Command handler not found."
            case .errorResponse(let description): return description
            case .requestFormatMismatch: return "Request format mismatch."
            case .responseFormatMismatch: return "Response format mismatch."
            }
        }
    }
}

/// Base request type
protocol UTMAPIHeader: Codable {
    /// Command to request
    var command: UTMAPI.Command { get }
}

protocol UTMAPIRequest: UTMAPIHeader {
    associatedtype Response: UTMAPIResponse
}

protocol UTMAPIResponse: UTMAPIHeader {
    associatedtype Request: UTMAPIRequest
}

// MARK: - Pre-parsed requests
extension UTMAPI {
    struct AnyRequest: UTMAPIRequest {
        typealias Response = AnyResponse
        
        private(set) var command: Command
    }
    
    struct AnyResponse: UTMAPIResponse {
        typealias Request = AnyRequest
        
        private(set) var command: Command
    }
}

// MARK: - Error response
extension UTMAPI {
    struct ErrorResponse: UTMAPIResponse {
        typealias Request = AnyRequest
        
        private(set) var command: Command = .error
        
        /// Error description string
        var error: String
        
        init(_ error: String) {
            self.error = error
        }
    }
}

// MARK: - List command
extension UTMAPI {
    /// List request
    class ListRequest: UTMAPIRequest {
        typealias Response = ListResponse
        
        private(set) var command: Command = .list
    }
    
    /// List response
    class ListResponse: UTMAPIResponse {
        typealias Request = ListRequest
        
        private(set) var command: Command = .list
        
        /// List response entry
        struct Entry: Codable {
            /// UUID string (preferred way to identify a VM)
            var uuid: String
            
            /// User specified name
            var name: String
            
            /// Current status of the VM
            var status: VMStatus
        }
        
        /// All registered VMs and their status
        var entries: [Entry] = []
    }
}

// MARK: - Status command
extension UTMAPI {
    class StatusRequest: UTMAPIRequest {
        typealias Response = StatusResponse
        
        private(set) var command: Command = .status
        
        /// Either a UUID string (preferred) or the user specified name
        var identifier: String = ""
    }
    
    class StatusResponse: UTMAPIResponse {
        typealias Request = StatusRequest
        
        private(set) var command: Command = .status
        
        /// Returned VM status
        var status: VMStatus = .unknown
    }
}

// MARK: - Start command
extension UTMAPI {
    class StartRequest: UTMAPIRequest {
        typealias Response = StartResponse
        
        private(set) var command: Command = .start
        
        /// Either a UUID string (preferred) or the user specified name
        var identifier: String = ""
    }
    
    class StartResponse: UTMAPIResponse {
        typealias Request = StartRequest
        
        private(set) var command: Command = .start
    }
}

// MARK: - Suspend command
extension UTMAPI {
    class SuspendRequest: UTMAPIRequest {
        typealias Response = SuspendResponse
        
        private(set) var command: Command = .suspend
        
        /// Either a UUID string (preferred) or the user specified name
        var identifier: String = ""
    }
    
    class SuspendResponse: UTMAPIResponse {
        typealias Request = SuspendRequest
        
        private(set) var command: Command = .suspend
    }
}

// MARK: - Stop command
extension UTMAPI {
    enum VMStopType: String, Codable {
        case force
        case kill
        case request
    }
    
    class StopRequest: UTMAPIRequest {
        typealias Response = StopResponse
        
        private(set) var command: Command = .stop
        
        /// Either a UUID string (preferred) or the user specified name
        var identifier: String = ""
        
        /// Method to stop the VM
        var type: VMStopType = .force
    }
    
    class StopResponse: UTMAPIResponse {
        typealias Request = StopRequest
        
        private(set) var command: Command = .stop
    }
}

// MARK: - Serial command
extension UTMAPI {
    enum VMSerialAddress: Codable {
        case none
        case ptty(path: String)
        case tcp(address: String, port: Int)
    }
    
    class SerialRequest: UTMAPIRequest {
        typealias Response = SerialResponse
        
        private(set) var command: Command = .serial
        
        /// Either a UUID string (preferred) or the user specified name
        var identifier: String = ""
        
        /// Optionally specify an index, otherwise the default serial will be returned
        var index: Int?
    }
    
    class SerialResponse: UTMAPIResponse {
        typealias Request = SerialRequest
        
        private(set) var command: Command = .serial
        
        /// Return an address to connect to (or none if no serial exists)
        var address: VMSerialAddress = .none
        
        /// Return the total number of serial ports supported
        var total: Int = 0
    }
}

/// Extension to support `SOCK_STREAM` Unix sockets
enum UnixStreamProtocol: Int32, Codable, SocketProtocol {
    case stream = 0
    
    public static var family: SocketAddressFamily { .unix }
    
    public var type: SocketType {
        switch self {
        case .stream: return .stream
        }
    }
}
