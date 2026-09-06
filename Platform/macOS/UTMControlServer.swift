import Foundation
import Darwin

@MainActor
final class UTMControlServer {
    private let data: UTMData
    private let readinessTask: Task<Void, Never>
    private let descriptor: Int32
    private let source: DispatchSourceRead
    private let socketPath: String
    private let socketLockPath: String
    private let socketIdentity: SocketIdentity
    private var lifecycleGates: [ObjectIdentifier: VMOperationGate] = [:]

    private struct SocketIdentity {
        let device: dev_t
        let inode: ino_t
    }

    init(data: UTMData, readinessTask: Task<Void, Never>) throws {
        self.data = data
        self.readinessTask = readinessTask
        guard let url = UTMControlSocket.url else { throw ServerError.unavailable() }
        socketPath = url.path
        socketLockPath = url.path + ".lock"
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ServerError.unavailable("create directory \(directory.path): \(error.localizedDescription)")
        }
        let lockDescriptor = try Self.acquireSocketLock(at: socketLockPath)
        defer {
            flock(lockDescriptor, LOCK_UN)
            close(lockDescriptor)
        }
        try Self.removeStaleSocket(at: url.path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ServerError.unavailable("socket: \(Self.posixError())") }
        self.descriptor = descriptor
        do {
            try UTMControlTransport.configure(descriptor)
            try UTMControlTransport.makeNonblocking(descriptor)
        } catch {
            close(descriptor)
            throw ServerError.unavailable("configure socket \(url.path): \(Self.posixError())")
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(url.path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            close(descriptor)
            throw ServerError.unavailable("socket path is too long")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.initializeMemory(as: UInt8.self, repeating: 0)
            pathBytes.withUnsafeBytes { destination.copyBytes(from: $0) }
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, Darwin.listen(descriptor, 8) == 0 else {
            let error = Self.posixError()
            close(descriptor)
            throw ServerError.unavailable("bind/listen \(url.path): \(error)")
        }
        guard chmod(url.path, mode_t(S_IRUSR | S_IWUSR)) == 0 else {
            let error = Self.posixError()
            close(descriptor)
            throw ServerError.unavailable("chmod \(url.path): \(error)")
        }
        var socketInfo = stat()
        guard lstat(url.path, &socketInfo) == 0 else {
            let error = Self.posixError()
            close(descriptor)
            throw ServerError.unavailable("inspect bound socket \(url.path): \(error)")
        }
        socketIdentity = SocketIdentity(device: socketInfo.st_dev, inode: socketInfo.st_ino)
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .global(qos: .userInitiated))
        self.source = source
        source.setEventHandler { [weak self] in self?.acceptConnections() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    deinit {
        source.cancel()
        guard let lockDescriptor = try? Self.acquireSocketLock(at: socketLockPath) else { return }
        defer {
            flock(lockDescriptor, LOCK_UN)
            close(lockDescriptor)
        }
        var socketInfo = stat()
        guard lstat(socketPath, &socketInfo) == 0,
              socketInfo.st_dev == socketIdentity.device,
              socketInfo.st_ino == socketIdentity.inode else { return }
        unlink(socketPath)
    }

    private func acceptConnections() {
        while true {
            let client = accept(descriptor, nil, nil)
            if client < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { return }
                return
            }
            do {
                try UTMControlTransport.configure(client)
                try UTMControlTransport.makeNonblocking(client)
            } catch {
                close(client)
                continue
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                Self.handle(client: client, server: self)
            }
        }
    }

    nonisolated private static func handle(client: Int32, server: UTMControlServer?) {
        let requestData: Data
        do {
            requestData = try UTMControlTransport.readFrame(from: client)
        } catch {
            close(client)
            return
        }
        guard let server else {
            close(client)
            return
        }
        Task { @MainActor in
            defer { close(client) }
            let response = await server.response(for: requestData)
            guard var output = try? JSONEncoder().encode(response) else { return }
            output.append(10)
            try? UTMControlTransport.writeAll(output, to: client)
        }
    }

    private func response(for requestData: Data) async -> UTMControlResponse {
        await readinessTask.value
        guard let request = try? JSONDecoder().decode(UTMControlRequest.self, from: requestData) else {
            return .failure(UTMControlError(code: UTMControlErrorCode.protocolError,
                                            message: "Invalid control request.", identifier: nil, retryable: false))
        }
        switch request {
        case .list:
            do {
                return .list(try data.virtualMachines.map(record))
            } catch {
                return .failure(ControlRecordError.backendUnavailable.controlError())
            }
        case .status(let identifier):
            do {
                return .status(try record(try resolve(identifier)))
            } catch let error as LookupError {
                return .failure(error.controlError(identifier: identifier))
            } catch {
                return .failure(ControlRecordError.backendUnavailable.controlError(identifier: identifier))
            }
        case .start(let identifier):
            return await perform(.start, identifier: identifier)
        case .stop(let identifier):
            return await perform(.stop, identifier: identifier)
        case .forceStop(let identifier):
            return await perform(.forceStop, identifier: identifier)
        case .suspend(let identifier):
            return await perform(.suspend, identifier: identifier)
        case .resume(let identifier):
            return await perform(.resume, identifier: identifier)
        case .clone(let identifier, let name):
            return await perform(.clone(name: name), identifier: identifier)
        case .delete(let identifier):
            return await perform(.delete, identifier: identifier)
        }
    }

    private enum Operation {
        case start, stop, forceStop, suspend, resume
        case clone(name: String?), delete

        var rawValue: String {
            switch self {
            case .start: return "start"
            case .stop: return "stop"
            case .forceStop: return "force-stop"
            case .suspend: return "suspend"
            case .resume: return "resume"
            case .clone: return "clone"
            case .delete: return "delete"
            }
        }
    }

    private func perform(_ operation: Operation, identifier: String) async -> UTMControlResponse {
        do {
            let vm = try resolve(identifier)
            let key = ObjectIdentifier(vm)
            let gate = lifecycleGates[key] ?? {
                let gate = VMOperationGate()
                lifecycleGates[key] = gate
                return gate
            }()
            return await gate.perform { @MainActor [weak self, weak vm] wasQueued in
                guard let self, let vm,
                      self.data.virtualMachines.contains(where: { $0 === vm }) else {
                    return .failure(UTMControlError(code: UTMControlErrorCode.notFound,
                                                    message: "Virtual machine not found.", identifier: identifier, retryable: false))
                }
                return await self.performSerialized(operation, vm: vm, identifier: identifier, wasQueued: wasQueued)
            }
        } catch let error as LookupError {
            return .failure(error.controlError(identifier: identifier))
        } catch {
            return .failure(UTMControlError(code: UTMControlErrorCode.backendFailure,
                                            message: "The virtual machine operation failed.", identifier: identifier, retryable: false))
        }
    }

    private func performSerialized(_ operation: Operation, vm: VMData, identifier: String, wasQueued: Bool) async -> UTMControlResponse {
        do {
            guard let wrapped = vm.wrapped else { throw ControlOperationError.vmUnavailable }
            switch operation {
            case .start:
                guard vm.state == .stopped else { throw ControlOperationError.invalidState }
                try await data.startForControl(vm: vm)
                try await waitForState(vm, expected: .started, timeout: 15)
            case .stop:
                if vm.state == .stopping {
                    try await waitForStopped(vm)
                } else if wasQueued && vm.state == .stopped {
                    return .operation(operation.rawValue, try record(vm))
                } else {
                    guard vm.state == .started || vm.state == .paused else { throw ControlOperationError.invalidState }
                    if vm.state == .paused {
                        try await wrapped.resume()
                        vm.state = wrapped.state
                    }
                    try await wrapped.stop(usingMethod: .request)
                    try await waitForStopped(vm)
                }
            case .forceStop:
                guard vm.state == .started || vm.state == .paused || vm.state == .stopped else {
                    throw ControlOperationError.invalidState
                }
                if wrapped.registryEntry.isSuspended {
                    try await wrapped.deleteSnapshot(name: nil)
                }
                if vm.state != .stopped {
                    try await wrapped.stop(usingMethod: .force)
                    try await waitForStopped(vm)
                }
            case .suspend:
                guard vm.state == .started else { throw ControlOperationError.invalidState }
                try await wrapped.pause()
                vm.state = wrapped.state
                try await waitForState(vm, expected: .paused, timeout: 15)
            case .resume:
                guard vm.state == .paused else { throw ControlOperationError.invalidState }
                try await wrapped.resume()
                vm.state = wrapped.state
                try await waitForState(vm, expected: .started, timeout: 15)
            case .clone(let name):
                guard let wrapped = vm.wrapped else { throw ControlOperationError.vmUnavailable }
                guard vm.state == .stopped else { throw ControlOperationError.invalidState }
                let cloned = try await data.clone(vm: vm)
                if let name {
                    if let config = cloned.wrapped?.config as? UTMQemuConfiguration {
                        config.information.name = name
                    } else if #available(macOS 11, *), let config = cloned.wrapped?.config as? UTMAppleConfiguration {
                        config.information.name = name
                    } else {
                        throw ControlOperationError.vmUnavailable
                    }
                    try await data.save(vm: cloned)
                }
                guard cloned.id != vm.id,
                      data.virtualMachines.contains(where: { $0 === cloned }) else {
                    throw ControlOperationError.vmUnavailable
                }
                return .operation(operation.rawValue, try record(cloned))
            case .delete:
                guard vm.state == .stopped else { throw ControlOperationError.invalidState }
                try await data.delete(vm: vm, alsoRegistry: true)
                guard !data.virtualMachines.contains(where: { $0 === vm }) else {
                    throw ControlOperationError.vmUnavailable
                }
                return .operation(operation.rawValue, UTMControlVM(uuid: vm.id.uuidString,
                                                                    name: vm.detailsTitleLabel,
                                                                    state: "deleted",
                                                                    backend: "unknown",
                                                                    loaded: false))
            }
            return .operation(operation.rawValue, try record(vm))
        } catch let error as ControlOperationError {
            return .failure(error.controlError(identifier: identifier))
        } catch let error as ControlRecordError {
            return .failure(error.controlError(identifier: identifier))
        } catch {
            return .failure(UTMControlError(code: UTMControlErrorCode.backendFailure,
                                            message: "The virtual machine operation failed.", identifier: identifier, retryable: false))
        }
    }

    private func waitForStopped(_ vm: VMData) async throws {
        let deadline = Date().addingTimeInterval(45)
        while vm.state != .stopped {
            guard Date() < deadline else { throw ControlOperationError.powerDownTimeout }
            try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        }
    }

    private func waitForState(_ vm: VMData, expected: UTMVirtualMachineState, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while vm.state != expected {
            guard Date() < deadline else { throw ControlOperationError.operationTimeout }
            try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        }
    }

    private func resolve(_ identifier: String) throws -> VMData {
        if let uuid = UUID(uuidString: identifier) {
            guard let vm = data.virtualMachines.first(where: { $0.id == uuid }) else { throw LookupError.notFound }
            return vm
        }
        let matches = data.virtualMachines.filter { $0.detailsTitleLabel == identifier }
        guard matches.count <= 1 else { throw LookupError.ambiguous }
        guard let vm = matches.first else { throw LookupError.notFound }
        return vm
    }

    private func record(_ vm: VMData) throws -> UTMControlVM {
        let backend: UTMBackend
        if let wrapped = vm.wrapped {
            backend = wrapped.config.backend
        } else {
            do { backend = try UTMQemuConfiguration.load(from: vm.pathUrl).backend }
            catch { throw ControlRecordError.backendUnavailable }
        }
        guard backend == .qemu || backend == .apple else { throw ControlRecordError.backendUnavailable }
        return UTMControlVM(uuid: vm.id.uuidString, name: vm.detailsTitleLabel,
                            state: vm.state.controlName, backend: backend == .qemu ? "qemu" : "apple", loaded: vm.isLoaded)
    }

    private static func removeStaleSocket(at path: String) throws {
        var info = stat()
        if lstat(path, &info) != 0 {
            guard errno == ENOENT else { throw ServerError.unavailable("inspect socket path \(path): \(Self.posixError())") }
            return
        }
        guard (info.st_mode & S_IFMT) == S_IFSOCK else {
            throw ServerError.unavailable("refusing to replace non-socket path \(path)")
        }
        for attempt in 0..<3 {
            let probe = socket(AF_UNIX, SOCK_STREAM, 0)
            guard probe >= 0 else { throw ServerError.unavailable("probe socket \(path): \(Self.posixError())") }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8) + [0]
            withUnsafeMutableBytes(of: &address.sun_path) { destination in
                bytes.withUnsafeBytes { destination.copyBytes(from: $0) }
            }
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(probe, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            let connectError = errno
            close(probe)
            if result == 0 { throw ServerError.unavailable("control socket is already active at \(path)") }
            if connectError != ECONNREFUSED {
                if connectError == ENOENT { return }
                throw ServerError.unavailable("inspect socket path \(path): \(String(cString: strerror(connectError)))")
            }
            if attempt < 2 { Thread.sleep(forTimeInterval: 0.05) }
        }
        guard unlink(path) == 0 else { throw ServerError.unavailable("remove stale socket \(path): \(Self.posixError())") }
    }

    nonisolated private static func acquireSocketLock(at path: String) throws -> Int32 {
        let descriptor = open(path, O_CREAT | O_RDWR | O_NONBLOCK, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else { throw ServerError.unavailable("open socket lock \(path): \(Self.posixError())") }
        guard fchmod(descriptor, mode_t(S_IRUSR | S_IWUSR)) == 0,
              flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let error = Self.posixError()
            close(descriptor)
            throw ServerError.unavailable("acquire socket lock \(path): \(error)")
        }
        return descriptor
    }

    nonisolated private static func posixError() -> String {
        String(cString: strerror(errno))
    }

    private enum LookupError: Error {
        case notFound, ambiguous
        func controlError(identifier: String) -> UTMControlError {
            switch self {
            case .notFound:
                return UTMControlError(code: UTMControlErrorCode.notFound, message: "Virtual machine not found.", identifier: identifier, retryable: false)
            case .ambiguous:
                return UTMControlError(code: UTMControlErrorCode.ambiguous, message: "More than one virtual machine has this exact name.", identifier: identifier, retryable: false)
            }
        }
    }

    private enum ControlRecordError: Error {
        case backendUnavailable
        func controlError(identifier: String? = nil) -> UTMControlError {
            UTMControlError(code: "BACKEND_UNAVAILABLE", message: "The virtual machine backend could not be determined from its configuration.", identifier: identifier, retryable: false)
        }
    }

    private enum ControlOperationError: Error {
        case invalidState, vmUnavailable, powerDownTimeout, operationTimeout

        func controlError(identifier: String) -> UTMControlError {
            switch self {
            case .invalidState:
                return UTMControlError(code: UTMControlErrorCode.invalidState,
                                       message: "The virtual machine is not in a valid state for this operation.", identifier: identifier, retryable: false)
            case .vmUnavailable:
                return UTMControlError(code: UTMControlErrorCode.vmUnavailable,
                                       message: "The virtual machine is not loaded.", identifier: identifier, retryable: false)
            case .powerDownTimeout:
                return UTMControlError(code: UTMControlErrorCode.powerDownTimeout,
                                       message: "Timed out waiting for the virtual machine to reach the stopped state after a graceful power-down request.", identifier: identifier, retryable: true)
            case .operationTimeout:
                return UTMControlError(code: UTMControlErrorCode.operationTimeout,
                                       message: "Timed out waiting for the virtual machine to reach the requested state.", identifier: identifier, retryable: true)
            }
        }
    }
    private enum ServerError: Error, LocalizedError {
        case unavailable(String = "native control server unavailable")

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): return message
            }
        }
    }
}

@MainActor
private final class VMOperationGate {
    private var previous: Task<UTMControlResponse, Never>?

    func perform(_ operation: @escaping @MainActor (Bool) async -> UTMControlResponse) async -> UTMControlResponse {
        let prior = previous
        let current = Task { @MainActor in
            _ = await prior?.value
            return await operation(prior != nil)
        }
        previous = current
        return await current.value
    }
}

private extension UTMVirtualMachineState {
    var controlName: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .started: return "started"
        case .pausing: return "pausing"
        case .paused: return "paused"
        case .resuming: return "resuming"
        case .saving: return "saving"
        case .restoring: return "restoring"
        case .stopping: return "stopping"
        }
    }
}
