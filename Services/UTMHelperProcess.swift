//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

#if os(iOS) || os(visionOS)
import Foundation
import ExtensionFoundation

@available(iOS 26, visionOS 26, *)
extension AppExtensionPoint {
    /// Hosts the helper that runs QEMU tools such as qemu-img out of process
    @Definition
    static var qemuHelper: AppExtensionPoint {
        Name("qemu-helper")
        UserInterface(false)
    }
}

/// A helper extension process that runs a QEMU tool once for the app.
///
/// Helpers run one at a time: the system hands out a helper process that is still going away
/// to a launch that comes too soon after it, and each process can run QEMU only once.
final class UTMHelperProcess {
    /// The helper extension exists in this build and can run on this system
    static var isSupported: Bool {
        #if os(visionOS)
        // visionOS installs extensions only for Apple's extension points, so the helper is not built
        return false
        #else
        if #available(iOS 26, *) {
            return true
        } else {
            return false
        }
        #endif
    }

    private static let gate = UTMHelperProcessGate()
    private static let exitTimeout: TimeInterval = 2

    /// Connection to the helper, to be configured and resumed by the owner
    let connection: NSXPCConnection
    /// The helper went away before it was asked to, such as when it failed to start
    private(set) var isLost = false
    /// Set when the system has seen the helper process go away
    private let exit: UTMHelperProcessSignal
    private let invalidation: () -> Void
    private var isInvalidated = false

    private init(connection: NSXPCConnection, exit: UTMHelperProcessSignal, invalidation: @escaping () -> Void) {
        self.connection = connection
        self.exit = exit
        self.invalidation = invalidation
    }

    deinit {
        invalidate()
    }

    /// Launch a helper and connect to it, waiting for any helper that is still running
    static func launch() async throws -> UTMHelperProcess {
        guard isSupported, #available(iOS 26, visionOS 26, *) else {
            throw UTMHelperProcessError.unsupported
        }
        await gate.acquire()
        do {
            let monitor = try await AppExtensionPoint.Monitor(appExtensionPoint: .qemuHelper)
            guard let identity = monitor.identities.first else {
                throw UTMHelperProcessError.notFound
            }
            let exit = UTMHelperProcessSignal()
            let configuration = AppExtensionProcess.Configuration(appExtensionIdentity: identity) {
                exit.signal()
            }
            let process = try await AppExtensionProcess(configuration: configuration)
            let connection = try process.makeXPCConnection()
            let helper = UTMHelperProcess(connection: connection, exit: exit) {
                process.invalidate()
            }
            connection.interruptionHandler = { [weak helper] in
                helper?.isLost = true
            }
            return helper
        } catch {
            await gate.release()
            throw error
        }
    }

    /// Ask the helper to exit and wait for the system to see it go, then let the next helper launch
    func terminate() async {
        guard !isInvalidated else {
            return
        }
        isInvalidated = true
        // this exit is the one asked for
        connection.interruptionHandler = nil
        (connection.remoteObjectProxy as? QEMUHelperProtocol)?.terminate()
        await exit.wait(timeout: Self.exitTimeout)
        connection.invalidate()
        invalidation()
        await Self.gate.release()
    }

    /// End the helper without waiting for it
    func invalidate() {
        guard !isInvalidated else {
            return
        }
        isInvalidated = true
        connection.invalidate()
        invalidation()
        Task {
            await Self.gate.release()
        }
    }
}

/// Lets one helper run at a time
private actor UTMHelperProcessGate {
    private var isHeld = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

/// A one-time event that can be waited for with a timeout
private final class UTMHelperProcessSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var isSignaled = false
    private var continuation: CheckedContinuation<Void, Never>?

    func signal() {
        lock.lock()
        isSignaled = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }

    func wait(timeout: TimeInterval) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            guard !isSignaled else {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                self.signal()
            }
        }
    }
}

enum UTMHelperProcessError: Error {
    case unsupported
    case notFound
    case lost
}

extension UTMHelperProcessError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupported: return NSLocalizedString("This operation requires a newer version of iOS.", comment: "UTMHelperProcess")
        case .notFound: return NSLocalizedString("The helper for this operation is not installed.", comment: "UTMHelperProcess")
        case .lost: return NSLocalizedString("The helper for this operation quit unexpectedly.", comment: "UTMHelperProcess")
        }
    }
}
#endif
