//
// Copyright © 2026 osy. All rights reserved.
//

import Foundation
import Darwin
import Security

enum UTMControlLaunchOptions {
    static let autoStartIntentFileName = "utmctl-autostart-intent"
    static let intentValidityInterval: TimeInterval = 60
}

struct UTMControlLaunchIntent: Codable {
    let processIdentifier: Int32
    let timestamp: TimeInterval

    func isValid(at date: Date = Date()) -> Bool {
        let age = date.timeIntervalSince1970 - timestamp
        guard age >= 0, age <= UTMControlLaunchOptions.intentValidityInterval else {
            return false
        }
        let result = kill(processIdentifier, 0)
        return result == 0 || errno == EPERM
    }
}

enum UTMControlRequest: Codable {
    case list
    case status(identifier: String)
    case start(identifier: String)
    case stop(identifier: String)
    case forceStop(identifier: String)
    case suspend(identifier: String)
    case resume(identifier: String)
    case clone(identifier: String, name: String?)
    case delete(identifier: String)
    case ipAddress(identifier: String)
    case snapshotCreate(identifier: String, name: String)
    case snapshotList(identifier: String)
    case snapshotRestore(identifier: String, name: String)
    case snapshotDelete(identifier: String, name: String)
    case usbList
    case usbConnect(identifier: String, device: String)
    case usbDisconnect(device: String)
    case exec(identifier: String, path: String, argv: [String], environment: [String], input: Data)

    private enum CodingKeys: String, CodingKey { case command, identifier, name, path, argv, environment, input }
    private enum Command: String, Codable {
        case list, status, start, stop, forceStop = "force-stop", suspend, resume, clone, delete
        case ipAddress = "ip-address"
        case snapshotCreate = "snapshot-create"
        case snapshotList = "snapshot-list"
        case snapshotRestore = "snapshot-restore"
        case snapshotDelete = "snapshot-delete"
        case usbList = "usb-list"
        case usbConnect = "usb-connect"
        case usbDisconnect = "usb-disconnect"
        case exec
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Command.self, forKey: .command) {
        case .list: self = .list
        case .status: self = .status(identifier: try container.decode(String.self, forKey: .identifier))
        case .start: self = .start(identifier: try container.decode(String.self, forKey: .identifier))
        case .stop: self = .stop(identifier: try container.decode(String.self, forKey: .identifier))
        case .forceStop: self = .forceStop(identifier: try container.decode(String.self, forKey: .identifier))
        case .suspend: self = .suspend(identifier: try container.decode(String.self, forKey: .identifier))
        case .resume: self = .resume(identifier: try container.decode(String.self, forKey: .identifier))
        case .clone:
            self = .clone(identifier: try container.decode(String.self, forKey: .identifier),
                          name: try container.decodeIfPresent(String.self, forKey: .name))
        case .delete: self = .delete(identifier: try container.decode(String.self, forKey: .identifier))
        case .ipAddress: self = .ipAddress(identifier: try container.decode(String.self, forKey: .identifier))
        case .snapshotCreate: self = .snapshotCreate(identifier: try container.decode(String.self, forKey: .identifier), name: try container.decode(String.self, forKey: .name))
        case .snapshotList: self = .snapshotList(identifier: try container.decode(String.self, forKey: .identifier))
        case .snapshotRestore: self = .snapshotRestore(identifier: try container.decode(String.self, forKey: .identifier), name: try container.decode(String.self, forKey: .name))
        case .snapshotDelete: self = .snapshotDelete(identifier: try container.decode(String.self, forKey: .identifier), name: try container.decode(String.self, forKey: .name))
        case .usbList: self = .usbList
        case .usbConnect: self = .usbConnect(identifier: try container.decode(String.self, forKey: .identifier), device: try container.decode(String.self, forKey: .name))
        case .usbDisconnect: self = .usbDisconnect(device: try container.decode(String.self, forKey: .name))
        case .exec:
            self = .exec(identifier: try container.decode(String.self, forKey: .identifier),
                        path: try container.decode(String.self, forKey: .path),
                        argv: try container.decode([String].self, forKey: .argv),
                        environment: try container.decode([String].self, forKey: .environment),
                        input: try container.decode(Data.self, forKey: .input))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .list: try container.encode(Command.list, forKey: .command)
        case .status(let identifier):
            try container.encode(Command.status, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .start(let identifier):
            try container.encode(Command.start, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .stop(let identifier):
            try container.encode(Command.stop, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .forceStop(let identifier):
            try container.encode(Command.forceStop, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .suspend(let identifier):
            try container.encode(Command.suspend, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .resume(let identifier):
            try container.encode(Command.resume, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .clone(let identifier, let name):
            try container.encode(Command.clone, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encodeIfPresent(name, forKey: .name)
        case .delete(let identifier):
            try container.encode(Command.delete, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .ipAddress(let identifier):
            try container.encode(Command.ipAddress, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .snapshotCreate(let identifier, let name):
            try container.encode(Command.snapshotCreate, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(name, forKey: .name)
        case .snapshotList(let identifier):
            try container.encode(Command.snapshotList, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
        case .snapshotRestore(let identifier, let name):
            try container.encode(Command.snapshotRestore, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(name, forKey: .name)
        case .snapshotDelete(let identifier, let name):
            try container.encode(Command.snapshotDelete, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(name, forKey: .name)
        case .usbList:
            try container.encode(Command.usbList, forKey: .command)
        case .usbConnect(let identifier, let device):
            try container.encode(Command.usbConnect, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(device, forKey: .name)
        case .usbDisconnect(let device):
            try container.encode(Command.usbDisconnect, forKey: .command)
            try container.encode(device, forKey: .name)
        case .exec(let identifier, let path, let argv, let environment, let input):
            try container.encode(Command.exec, forKey: .command)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(path, forKey: .path)
            try container.encode(argv, forKey: .argv)
            try container.encode(environment, forKey: .environment)
            try container.encode(input, forKey: .input)
        }
    }
}

enum UTMControlExecLimits {
    static let maximumInputBytes = 256 * 1024
    static let maximumOutputBytes = 256 * 1024
    static let timeout: TimeInterval = 30
}

struct UTMControlVM: Codable {
    let uuid: String
    let name: String
    let state: String
    let backend: String
    let loaded: Bool
}

struct UTMControlResponse: Codable {
    let schema: Int
    let command: String?
    let vms: [UTMControlVM]?
    let vm: UTMControlVM?
    let ipAddresses: [String]?
    let snapshotNames: [String]?
    let usbDevices: [UTMControlUSBDevice]?
    let execResult: UTMControlExecResult?
    let error: UTMControlError?

    static func list(_ vms: [UTMControlVM]) -> Self {
        Self(schema: 1, command: "list", vms: vms, vm: nil, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: nil, error: nil)
    }

    static func status(_ vm: UTMControlVM) -> Self {
        Self(schema: 1, command: "status", vms: nil, vm: vm, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: nil, error: nil)
    }

    static func operation(_ command: String, _ vm: UTMControlVM) -> Self {
        Self(schema: 1, command: command, vms: nil, vm: vm, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: nil, error: nil)
    }

    static func ipAddress(_ vm: UTMControlVM, addresses: [String]) -> Self {
        Self(schema: 1, command: "ip-address", vms: nil, vm: vm, ipAddresses: addresses, snapshotNames: nil, usbDevices: nil, execResult: nil, error: nil)
    }

    static func snapshots(_ vm: UTMControlVM, names: [String]) -> Self {
        Self(schema: 1, command: "snapshot-list", vms: nil, vm: vm, ipAddresses: nil, snapshotNames: names, usbDevices: nil, execResult: nil, error: nil)
    }

    static func usbList(_ devices: [UTMControlUSBDevice]) -> Self {
        Self(schema: 1, command: "usb-list", vms: nil, vm: nil, ipAddresses: nil, snapshotNames: nil, usbDevices: devices, execResult: nil, error: nil)
    }

    static func success(_ command: String) -> Self {
        Self(schema: 1, command: command, vms: nil, vm: nil, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: nil, error: nil)
    }

    static func failure(_ error: UTMControlError) -> Self {
        Self(schema: 1, command: nil, vms: nil, vm: nil, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: nil, error: error)
    }

    static func exec(_ result: UTMControlExecResult) -> Self {
        Self(schema: 1, command: "exec", vms: nil, vm: nil, ipAddresses: nil, snapshotNames: nil, usbDevices: nil, execResult: result, error: nil)
    }
}

struct UTMControlExecResult: Codable {
    let exitCode: Int
    let stdout: Data
    let stderr: Data
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
}

struct UTMControlUSBDevice: Codable {
    let name: String
    let vendorId: Int
    let productId: Int
    let location: Int
}

struct UTMControlError: Codable {
    let code: String
    let message: String
    let identifier: String?
    let retryable: Bool
}

enum UTMControlErrorCode {
    static let unavailable = "UTM_UNAVAILABLE"
    static let notFound = "VM_NOT_FOUND"
    static let ambiguous = "AMBIGUOUS_VM_NAME"
    static let protocolError = "PROTOCOL_ERROR"
    static let invalidState = "INVALID_VM_STATE"
    static let vmUnavailable = "VM_UNAVAILABLE"
    static let backendUnavailable = "BACKEND_UNAVAILABLE"
    static let backendFailure = "BACKEND_FAILURE"
    static let usbDeviceNotFound = "USB_DEVICE_NOT_FOUND"
    static let ambiguousUSBDevice = "AMBIGUOUS_USB_DEVICE"
    static let usbFailure = "USB_FAILURE"
    static let snapshotFailure = "SNAPSHOT_FAILURE"
    static let operationTimeout = "OPERATION_TIMEOUT"
    static let powerDownTimeout = "POWER_DOWN_TIMEOUT"
    static let guestAgentUnavailable = "GUEST_AGENT_UNAVAILABLE"
    static let execFailure = "EXEC_FAILURE"
    static let execTimeout = "EXEC_TIMEOUT"
    static let execInputTooLarge = "EXEC_INPUT_TOO_LARGE"
}

enum UTMControlSocket {
    static let socketName = "control/utmctl.sock"

    static var launchIntentURL: URL? {
        url?.deletingLastPathComponent().appendingPathComponent(UTMControlLaunchOptions.autoStartIntentFileName)
    }

    static var applicationGroupIdentifier: String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String] else {
            return nil
        }
        return groups.first
    }

    static var url: URL? {
        guard let identifier = applicationGroupIdentifier else {
            return nil
        }

        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) ?? fallbackContainerURL(for: identifier) else {
            return nil
        }

        if container.lastPathComponent == "Data",
           container.deletingLastPathComponent().lastPathComponent == identifier {
            let library = container.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let groupContainer = library.appendingPathComponent("Group Containers", isDirectory: true)
                .appendingPathComponent(identifier, isDirectory: true)
            var info = stat()
            guard lstat(groupContainer.path, &info) == 0,
                  info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
                return nil
            }
            return groupContainer.appendingPathComponent(socketName)
        }

        return container.appendingPathComponent(socketName)
    }

    private static func fallbackContainerURL(for identifier: String) -> URL? {
        guard identifier.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]*$", options: .regularExpression) != nil,
              let passwd = getpwuid(getuid()) else {
            return nil
        }

        let home = String(cString: passwd.pointee.pw_dir)
        guard home.hasPrefix("/"), !home.contains("/../"), !home.hasSuffix("/..") else {
            return nil
        }
        let groupContainer = URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: true)
        var info = stat()
        guard lstat(groupContainer.path, &info) == 0,
              info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            return nil
        }
        return groupContainer
    }
}

enum UTMControlTransportError: Error { case unavailable, protocolError }

enum UTMControlTransport {
    static let timeout: TimeInterval = 10
    private static let maximumFrameSize = 1024 * 1024

    static func configure(_ descriptor: Int32) throws {
        var noSigPipe: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw UTMControlTransportError.unavailable
        }
    }

    static func makeNonblocking(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFL, 0)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw UTMControlTransportError.unavailable
        }
    }

    static func writeAll(_ data: Data, to descriptor: Int32) throws {
        let deadline = Date().addingTimeInterval(timeout)
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                try wait(for: descriptor, events: Int16(POLLOUT), until: deadline)
                let count = Darwin.write(descriptor, base.advanced(by: offset), bytes.count - offset)
                if count > 0 { offset += count }
                else if count < 0 && errno == EINTR { continue }
                else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) { continue }
                else { throw UTMControlTransportError.unavailable }
            }
        }
    }

    static func readFrame(from descriptor: Int32, timeout: TimeInterval = UTMControlTransport.timeout) throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        var frame = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            try wait(for: descriptor, events: Int16(POLLIN), until: deadline)
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { throw UTMControlTransportError.unavailable }
            if count < 0 {
                if errno == EINTR { continue }
                throw UTMControlTransportError.unavailable
            }
            frame.append(contentsOf: buffer[0..<count])
            if frame.contains(10) { return frame }
            if frame.count > maximumFrameSize { throw UTMControlTransportError.protocolError }
        }
    }

    private static func wait(for descriptor: Int32, events: Int16, until deadline: Date) throws {
        var pollDescriptor = pollfd(fd: descriptor, events: events, revents: 0)
        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw UTMControlTransportError.unavailable }
            let milliseconds = max(1, Int32(remaining * 1000))
            let result = Darwin.poll(&pollDescriptor, 1, milliseconds)
            if result > 0 {
                let errors = Int16(POLLERR | POLLNVAL)
                guard pollDescriptor.revents & errors == 0 else {
                    throw UTMControlTransportError.unavailable
                }
                return
            }
            if result < 0 && errno != EINTR { throw UTMControlTransportError.unavailable }
        }
    }
}

final class UTMControlClient {
    enum ClientError: Error { case unavailable, protocolError }

    func request(_ request: UTMControlRequest, responseTimeout: TimeInterval = UTMControlTransport.timeout) throws -> UTMControlResponse {
        guard let url = UTMControlSocket.url else { throw ClientError.unavailable }
        let descriptor = try connect(to: url.path)
        defer { close(descriptor) }
        var payload = try JSONEncoder().encode(request)
        payload.append(10)
        do { try UTMControlTransport.writeAll(payload, to: descriptor) }
        catch { throw ClientError.unavailable }
        let responseData: Data
        do { responseData = try UTMControlTransport.readFrame(from: descriptor, timeout: responseTimeout) }
        catch UTMControlTransportError.protocolError { throw ClientError.protocolError }
        catch { throw ClientError.unavailable }
        guard let response = try? JSONDecoder().decode(UTMControlResponse.self, from: responseData) else {
            throw ClientError.protocolError
        }
        return response
    }

    private func connect(to path: String) throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ClientError.unavailable }
        do { try UTMControlTransport.configure(descriptor); try UTMControlTransport.makeNonblocking(descriptor) }
        catch { close(descriptor); throw ClientError.unavailable }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            close(descriptor); throw ClientError.unavailable
        }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.initializeMemory(as: UInt8.self, repeating: 0)
            pathBytes.withUnsafeBytes { destination.copyBytes(from: $0) }
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { close(descriptor); throw ClientError.unavailable }
        return descriptor
    }
}
