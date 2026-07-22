//
// Copyright © 2026 osy. All rights reserved.
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

import AppKit
import Darwin
import Foundation
@preconcurrency import Virtualization

#if canImport(AccessoryAccess)
import AccessoryAccess
#endif

struct UTMAppleUSBDevice: Hashable, Identifiable, Sendable {
    enum State: Hashable, Sendable {
        case available
        case connected
        case inUse
    }

    let registryID: UInt64

    let identity: UTMRegistryEntry.AppleUSBDevice

    let name: String

    let state: State

    var id: UInt64 {
        registryID
    }
}

@MainActor protocol UTMAppleUSBManagerDelegate: AnyObject {
    func usbManager(_ usbManager: UTMAppleUSBManager, didDiscover device: UTMAppleUSBDevice)

    func usbManager(_ usbManager: UTMAppleUSBManager, didRemove device: UTMAppleUSBDevice)
}

private enum UTMAppleUSBManagerError: LocalizedError {
    case notSupported
    case dockIconRequired
    case noUsbController
    case virtualMachineNotRunning
    case deviceUnavailable
    case deviceInUse
    case invalidDeviceDescriptor

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("USB passthrough requires macOS 27 or later on an Apple Silicon Mac.", comment: "UTMAppleUSBManager")
        case .dockIconRequired:
            return NSLocalizedString("USB passthrough requires UTM to appear in the Dock. Enable “Show dock icon” in Settings, then restart UTM.", comment: "UTMAppleUSBManager")
        case .noUsbController:
            return NSLocalizedString("The virtual machine does not have a USB controller.", comment: "UTMAppleUSBManager")
        case .virtualMachineNotRunning:
            return NSLocalizedString("The virtual machine must be running to change USB devices.", comment: "UTMAppleUSBManager")
        case .deviceUnavailable:
            return NSLocalizedString("The USB device is no longer available.", comment: "UTMAppleUSBManager")
        case .deviceInUse:
            return NSLocalizedString("The USB device is connected to another virtual machine.", comment: "UTMAppleUSBManager")
        case .invalidDeviceDescriptor:
            return NSLocalizedString("The USB device provided an invalid descriptor.", comment: "UTMAppleUSBManager")
        }
    }
}

@available(macOS 11, *)
final class UTMAppleUSBManager: @unchecked Sendable {
    private let virtualMachineQueue: DispatchQueue

    private let ownerID = UUID()

    private let coordinatorLock = NSLock()

    private var coordinatorStorage: AnyObject?

    private let lifecycleLock = NSLock()

    private var pendingStopTask: Task<Void, Never>?

    @MainActor weak var delegate: (any UTMAppleUSBManagerDelegate)?

    @MainActor var onConnectedDevicesChange: (([UTMRegistryEntry.AppleUSBDevice]) -> Void)?

    init(virtualMachineQueue: DispatchQueue) {
        self.virtualMachineQueue = virtualMachineQueue
    }

    @MainActor var isAvailable: Bool {
        unavailableError == nil
    }

    @MainActor var isSupported: Bool {
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            return true
        }
        #endif
        return false
    }

    @MainActor var unavailableReason: String? {
        unavailableError?.localizedDescription
    }

    func start(with virtualMachine: VZVirtualMachine,
               restoring devices: [UTMRegistryEntry.AppleUSBDevice]) async throws {
        await waitForPendingStop()
        try await checkAvailability()
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            try await coordinator.start(with: virtualMachine, restoring: devices)
            return
        }
        #endif
        throw UTMAppleUSBManagerError.notSupported
    }

    func stop(with virtualMachine: VZVirtualMachine) {
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *), let coordinator = existingCoordinator {
            lifecycleLock.lock()
            let previousStopTask = pendingStopTask
            pendingStopTask = Task {
                await previousStopTask?.value
                await coordinator.stop(with: virtualMachine)
            }
            lifecycleLock.unlock()
        }
        #endif
    }

    func usbDevices() async throws -> [UTMAppleUSBDevice] {
        try await checkAvailability()
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            return try await coordinator.usbDevices()
        }
        #endif
        throw UTMAppleUSBManagerError.notSupported
    }

    func connect(_ device: UTMAppleUSBDevice) async throws {
        try await checkAvailability()
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            try await coordinator.connect(device)
            return
        }
        #endif
        throw UTMAppleUSBManagerError.notSupported
    }

    func disconnect(_ device: UTMAppleUSBDevice) async throws {
        try await checkAvailability()
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            try await coordinator.disconnect(device)
            return
        }
        #endif
        throw UTMAppleUSBManagerError.notSupported
    }

    func detachAllForSnapshot(with virtualMachine: VZVirtualMachine) async throws -> [UTMRegistryEntry.AppleUSBDevice] {
        let isAvailable = await isAvailable
        guard isAvailable else {
            return []
        }
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            return try await coordinator.detachAllForSnapshot(with: virtualMachine)
        }
        #endif
        return []
    }

    func releaseSnapshotReservations(for virtualMachine: VZVirtualMachine) async {
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *), let coordinator = existingCoordinator {
            await coordinator.releaseSnapshotReservations(for: virtualMachine)
        }
        #endif
    }

    func restoreConnections(from devices: [UTMRegistryEntry.AppleUSBDevice],
                            with virtualMachine: VZVirtualMachine) async throws {
        try await checkAvailability()
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            try await coordinator.restoreConnections(from: devices, with: virtualMachine)
            return
        }
        #endif
        throw UTMAppleUSBManagerError.notSupported
    }

    @MainActor private var unavailableError: UTMAppleUSBManagerError? {
        #if canImport(AccessoryAccess) && arch(arm64)
        if #available(macOS 27, *) {
            return NSApp.activationPolicy() == .regular ? nil : .dockIconRequired
        }
        #endif
        return .notSupported
    }

    private func checkAvailability() async throws {
        if let error = await unavailableError {
            throw error
        }
    }

    private func waitForPendingStop() async {
        let pendingStopTask = pendingStopTaskSnapshot()
        await pendingStopTask?.value
    }

    private func pendingStopTaskSnapshot() -> Task<Void, Never>? {
        lifecycleLock.lock()
        let pendingStopTask = pendingStopTask
        lifecycleLock.unlock()
        return pendingStopTask
    }

    @MainActor fileprivate func didDiscover(_ device: UTMAppleUSBDevice) {
        delegate?.usbManager(self, didDiscover: device)
    }

    @MainActor fileprivate func didRemove(_ device: UTMAppleUSBDevice) {
        delegate?.usbManager(self, didRemove: device)
    }

    @MainActor fileprivate func connectedDevicesDidChange(_ devices: [UTMRegistryEntry.AppleUSBDevice]) {
        onConnectedDevicesChange?(devices)
    }

    #if canImport(AccessoryAccess) && arch(arm64)
    @available(macOS 27, *)
    private var coordinator: UTMAppleUSBPassthroughCoordinator {
        coordinatorLock.lock()
        defer {
            coordinatorLock.unlock()
        }
        if let coordinator = coordinatorStorage as? UTMAppleUSBPassthroughCoordinator {
            return coordinator
        }
        let coordinator = UTMAppleUSBPassthroughCoordinator(owner: self,
                                                             ownerID: ownerID,
                                                             virtualMachineQueue: virtualMachineQueue)
        coordinatorStorage = coordinator
        return coordinator
    }

    @available(macOS 27, *)
    private var existingCoordinator: UTMAppleUSBPassthroughCoordinator? {
        coordinatorLock.lock()
        defer {
            coordinatorLock.unlock()
        }
        return coordinatorStorage as? UTMAppleUSBPassthroughCoordinator
    }
    #endif
}

#if canImport(AccessoryAccess) && arch(arm64)

private actor UTMAppleUSBOperationGate {
    private var isLocked = false

    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@available(macOS 27, *)
private struct UTMAppleUSBAccessoryClaim: @unchecked Sendable {
    let accessory: AAUSBAccessory

    let identity: UTMRegistryEntry.AppleUSBDevice

    let claimID: UUID
}

@available(macOS 27, *)
private struct UTMAppleUSBAccessoryEvent: Sendable {
    enum Kind: Sendable {
        case discovered
        case removed
    }

    let kind: Kind

    let registryID: UInt64

    let identity: UTMRegistryEntry.AppleUSBDevice

    let previousOwnerID: UUID?
}

@available(macOS 27, *)
private final class UTMAppleUSBAccessoryListener: NSObject, AAUSBAccessoryListener, @unchecked Sendable {
    weak var broker: UTMAppleUSBAccessoryBroker?

    private let eventTaskLock = NSLock()

    private var eventTask: Task<Void, Never>?

    init(broker: UTMAppleUSBAccessoryBroker) {
        self.broker = broker
    }

    func usbAccessoryDidConnect(_ usbAccessory: AAUSBAccessory) {
        enqueue(usbAccessory, isConnected: true)
    }

    func usbAccessoryDidDisconnect(_ usbAccessory: AAUSBAccessory) {
        enqueue(usbAccessory, isConnected: false)
    }

    private func enqueue(_ accessory: AAUSBAccessory, isConnected: Bool) {
        eventTaskLock.lock()
        let previousTask = eventTask
        eventTask = Task { [weak broker] in
            await previousTask?.value
            if isConnected {
                await broker?.accessoryDidConnect(accessory)
            } else {
                await broker?.accessoryDidDisconnect(accessory)
            }
        }
        eventTaskLock.unlock()
    }
}

@available(macOS 27, *)
private actor UTMAppleUSBAccessoryBroker {
    private struct Record {
        let accessory: AAUSBAccessory

        let identity: UTMRegistryEntry.AppleUSBDevice
    }

    private struct Ownership {
        let ownerID: UUID

        let claimID: UUID
    }

    static let shared = UTMAppleUSBAccessoryBroker()

    private var listener: UTMAppleUSBAccessoryListener?

    private var registrationTask: Task<[AAUSBAccessory], Error>?

    private var isRegistered = false

    private var records: [UInt64: Record] = [:]

    private var owners: [UInt64: Ownership] = [:]

    private var observers: [UUID: @Sendable (UTMAppleUSBAccessoryEvent) -> Void] = [:]

    func register() async throws {
        if isRegistered {
            return
        }
        let task: Task<[AAUSBAccessory], Error>
        if let registrationTask = registrationTask {
            task = registrationTask
        } else {
            let listener = makeListener()
            task = Task {
                try await AAUSBAccessoryManager.shared.registerListener(listener, matchingCriteria: [])
            }
            registrationTask = task
        }
        do {
            let accessories = try await task.value
            if !isRegistered {
                for accessory in accessories {
                    do {
                        let identity = try makeIdentity(for: accessory)
                        records[accessory.registryID] = Record(accessory: accessory, identity: identity)
                    } catch {
                        logger.debug("Failed to read USB device descriptor: \(error.localizedDescription)")
                    }
                }
                isRegistered = true
            }
            registrationTask = nil
        } catch {
            registrationTask = nil
            throw error
        }
    }

    func addObserver(ownerID: UUID, observer: @escaping @Sendable (UTMAppleUSBAccessoryEvent) -> Void) {
        observers[ownerID] = observer
    }

    func removeObserver(ownerID: UUID) {
        observers.removeValue(forKey: ownerID)
    }

    func devices(for ownerID: UUID) -> [UTMAppleUSBDevice] {
        records.values.map { record in
            let state: UTMAppleUSBDevice.State
            if let ownership = owners[record.accessory.registryID] {
                state = ownership.ownerID == ownerID ? .connected : .inUse
            } else {
                state = .available
            }
            return UTMAppleUSBDevice(registryID: record.accessory.registryID,
                                     identity: record.identity,
                                     name: record.identity.displayName,
                                     state: state)
        }.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.registryID < rhs.registryID
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func claim(device: UTMAppleUSBDevice, ownerID: UUID, claimID: UUID) throws -> UTMAppleUSBAccessoryClaim {
        guard let record = records[device.registryID],
              record.identity.deviceDescriptorData == device.identity.deviceDescriptorData else {
            throw UTMAppleUSBManagerError.deviceUnavailable
        }
        return try claim(record: record, ownerID: ownerID, claimID: claimID)
    }

    func claim(resolved identity: UTMRegistryEntry.AppleUSBDevice,
               ownerID: UUID,
               claimID: UUID) throws -> UTMAppleUSBAccessoryClaim? {
        guard let registryID = identity.registryID,
              let record = records[registryID],
              record.identity.deviceDescriptorData == identity.deviceDescriptorData else {
            return nil
        }
        return try claim(record: record, ownerID: ownerID, claimID: claimID)
    }

    func release(registryID: UInt64, ownerID: UUID, claimID: UUID? = nil) {
        guard let ownership = owners[registryID], ownership.ownerID == ownerID else {
            return
        }
        if let claimID = claimID, ownership.claimID != claimID {
            return
        }
        owners.removeValue(forKey: registryID)
    }

    func accessoryDidConnect(_ accessory: AAUSBAccessory) {
        do {
            let identity = try makeIdentity(for: accessory)
            records[accessory.registryID] = Record(accessory: accessory, identity: identity)
            notify(UTMAppleUSBAccessoryEvent(kind: .discovered,
                                             registryID: accessory.registryID,
                                             identity: identity,
                                             previousOwnerID: owners[accessory.registryID]?.ownerID))
        } catch {
            logger.debug("Failed to read USB device descriptor: \(error.localizedDescription)")
        }
    }

    func accessoryDidDisconnect(_ accessory: AAUSBAccessory) {
        let record = records.removeValue(forKey: accessory.registryID)
        let previousOwnerID = owners.removeValue(forKey: accessory.registryID)?.ownerID
        guard let identity = record?.identity ?? (try? makeIdentity(for: accessory)) else {
            return
        }
        notify(UTMAppleUSBAccessoryEvent(kind: .removed,
                                         registryID: accessory.registryID,
                                         identity: identity,
                                         previousOwnerID: previousOwnerID))
    }

    private func makeListener() -> UTMAppleUSBAccessoryListener {
        if let listener = listener {
            return listener
        }
        let listener = UTMAppleUSBAccessoryListener(broker: self)
        self.listener = listener
        return listener
    }

    private func claim(record: Record, ownerID: UUID, claimID: UUID) throws -> UTMAppleUSBAccessoryClaim {
        let registryID = record.accessory.registryID
        let activeClaimID: UUID
        if let ownership = owners[registryID] {
            guard ownership.ownerID == ownerID else {
                throw UTMAppleUSBManagerError.deviceInUse
            }
            activeClaimID = ownership.claimID
        } else {
            owners[registryID] = Ownership(ownerID: ownerID, claimID: claimID)
            activeClaimID = claimID
        }
        return UTMAppleUSBAccessoryClaim(accessory: record.accessory,
                                         identity: record.identity,
                                         claimID: activeClaimID)
    }

    private func notify(_ event: UTMAppleUSBAccessoryEvent) {
        for observer in observers.values {
            observer(event)
        }
    }
}

@available(macOS 27, *)
private final class UTMAppleUSBPassthroughCoordinator: NSObject, VZUSBController.Delegate, @unchecked Sendable {
    private struct Connection {
        let identity: UTMRegistryEntry.AppleUSBDevice

        let device: VZUSBPassthroughDevice

        let claimID: UUID
    }

    private struct ConnectionSnapshot: Sendable {
        let registryID: UInt64

        let identity: UTMRegistryEntry.AppleUSBDevice

        let claimID: UUID
    }

    private weak var owner: UTMAppleUSBManager?

    private let ownerID: UUID

    private let virtualMachineQueue: DispatchQueue

    private let broker = UTMAppleUSBAccessoryBroker.shared

    private let operationGate = UTMAppleUSBOperationGate()

    private var virtualMachine: VZVirtualMachine?

    private var connections: [UInt64: Connection] = [:]

    private var persistentConnections: [UTMRegistryEntry.AppleUSBDevice] = []

    private var reservedClaims: [UInt64: UUID] = [:]

    private var pendingClaims: [UInt64: UUID] = [:]

    private var pendingDetachClaims: [UInt64: UUID] = [:]

    private var generation = 0

    private var claimSessionID = UUID()

    private var isSuspended = true

    private let eventTaskLock = NSLock()

    private var eventTask: Task<Void, Never>?

    init(owner: UTMAppleUSBManager, ownerID: UUID, virtualMachineQueue: DispatchQueue) {
        self.owner = owner
        self.ownerID = ownerID
        self.virtualMachineQueue = virtualMachineQueue
    }

    deinit {
        let ownerID = ownerID
        Task {
            await UTMAppleUSBAccessoryBroker.shared.removeObserver(ownerID: ownerID)
        }
    }

    func start(with virtualMachine: VZVirtualMachine,
               restoring devices: [UTMRegistryEntry.AppleUSBDevice]) async throws {
        try await withOperationGate {
            try await startLocked(with: virtualMachine, restoring: devices)
        }
    }

    private func startLocked(with virtualMachine: VZVirtualMachine,
                             restoring devices: [UTMRegistryEntry.AppleUSBDevice]) async throws {
        let staleClaims = try await configure(virtualMachine: virtualMachine)
        for (registryID, claimID) in staleClaims {
            await broker.release(registryID: registryID, ownerID: ownerID, claimID: claimID)
        }
        await addObserver()
        await setPersistentConnections(devices)
        try await setSuspended(false)
        try await broker.register()
        try await restoreConnectionsLocked(from: devices)
    }

    func stop(with virtualMachine: VZVirtualMachine) async {
        await withOperationGate {
            await stopLocked(with: virtualMachine)
        }
    }

    private func stopLocked(with virtualMachine: VZVirtualMachine) async {
        let claims: [UInt64: UUID]? = await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                guard self.virtualMachine === virtualMachine else {
                    continuation.resume(returning: nil)
                    return
                }
                self.virtualMachine?.usbControllers.first?.delegate = nil
                self.virtualMachine = nil
                self.isSuspended = true
                self.generation += 1
                var claims = self.connections.mapValues(\.claimID)
                claims.merge(self.reservedClaims) { _, reservedClaimID in reservedClaimID }
                claims.merge(self.pendingClaims) { _, pendingClaimID in pendingClaimID }
                self.connections.removeAll()
                self.reservedClaims.removeAll()
                self.pendingClaims.removeAll()
                self.pendingDetachClaims.removeAll()
                continuation.resume(returning: claims)
            }
        }
        guard let claims = claims else {
            return
        }
        for (registryID, claimID) in claims {
            await broker.release(registryID: registryID, ownerID: ownerID, claimID: claimID)
        }
    }

    func usbDevices() async throws -> [UTMAppleUSBDevice] {
        await addObserver()
        try await broker.register()
        let devices = await broker.devices(for: ownerID)
        let connectedRegistryIDs = await connectedRegistryIDs()
        return devices.map { device in
            guard device.state == .connected, !connectedRegistryIDs.contains(device.registryID) else {
                return device
            }
            return UTMAppleUSBDevice(registryID: device.registryID,
                                     identity: device.identity,
                                     name: device.name,
                                     state: .available)
        }
    }

    func connect(_ device: UTMAppleUSBDevice) async throws {
        try await withOperationGate {
            try await connectLocked(device)
        }
    }

    private func connectLocked(_ device: UTMAppleUSBDevice) async throws {
        try await ensureVirtualMachineIsRunning()
        let claimSessionID = await claimSessionIDSnapshot()
        let claim = try await broker.claim(device: device, ownerID: ownerID, claimID: claimSessionID)
        do {
            if try await attach(claim) {
                await notifyConnectedDevicesChanged()
            }
        } catch {
            await releaseClaim(claim)
            throw error
        }
    }

    func disconnect(_ device: UTMAppleUSBDevice) async throws {
        try await withOperationGate {
            try await disconnectLocked(device)
        }
    }

    private func disconnectLocked(_ device: UTMAppleUSBDevice) async throws {
        try await ensureVirtualMachineIsRunning()
        let identity = try await detach(registryID: device.registryID, retainingOwnership: false)
        if identity != nil {
            await notifyConnectedDevicesChanged()
        }
    }

    func detachAllForSnapshot(with virtualMachine: VZVirtualMachine) async throws -> [UTMRegistryEntry.AppleUSBDevice] {
        try await withOperationGate {
            try await ensureCurrentVirtualMachineIsRunning(virtualMachine)
            return try await detachAllForSnapshotLocked()
        }
    }

    private func detachAllForSnapshotLocked() async throws -> [UTMRegistryEntry.AppleUSBDevice] {
        try await setSuspended(true)
        let connections = await connectionSnapshots()
        let persistentConnections = await persistentIdentities()
        do {
            for connection in connections {
                _ = try await detach(registryID: connection.registryID, retainingOwnership: true)
            }
            await notifyConnectedDevicesChanged()
            return persistentConnections
        } catch {
            try? await restoreConnectionsLocked(from: persistentConnections)
            throw error
        }
    }

    func releaseSnapshotReservations(for virtualMachine: VZVirtualMachine) async {
        await withOperationGate {
            if await isCurrentVirtualMachine(virtualMachine) {
                await releaseSnapshotReservationsLocked()
            }
        }
    }

    private func releaseSnapshotReservationsLocked() async {
        let claims: [UInt64: UUID] = await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                let claims = self.reservedClaims
                self.reservedClaims.removeAll()
                continuation.resume(returning: claims)
            }
        }
        for (registryID, claimID) in claims {
            await broker.release(registryID: registryID, ownerID: ownerID, claimID: claimID)
        }
    }

    func restoreConnections(from devices: [UTMRegistryEntry.AppleUSBDevice],
                            with virtualMachine: VZVirtualMachine) async throws {
        try await withOperationGate {
            try await ensureCurrentVirtualMachineIsRunning(virtualMachine)
            try await restoreConnectionsLocked(from: devices)
        }
    }

    private func restoreConnectionsLocked(from devices: [UTMRegistryEntry.AppleUSBDevice]) async throws {
        try await setSuspended(false)
        guard !devices.isEmpty else {
            await setPersistentConnections([])
            await notifyConnectedDevicesChanged()
            return
        }
        await addObserver()
        do {
            try await broker.register()
        } catch {
            await releaseSnapshotReservationsLocked()
            throw error
        }
        let availableDevices = await broker.devices(for: ownerID).filter {
            if case .inUse = $0.state {
                return false
            }
            return true
        }
        let resolvedDevices = devicesForRestore(devices, using: availableDevices)
        let claimSessionID = await claimSessionIDSnapshot()
        await setPersistentConnections(devices)
        var claimedRegistryIDs = Set<UInt64>()
        for (savedIdentity, resolvedIdentity) in zip(devices, resolvedDevices) {
            guard let identity = resolvedIdentity else {
                logger.debug("Saved USB device is not currently available or cannot be identified unambiguously: \(savedIdentity.displayName)")
                continue
            }
            do {
                guard let claim = try await broker.claim(resolved: identity,
                                                         ownerID: ownerID,
                                                         claimID: claimSessionID) else {
                    logger.debug("Saved USB device is not currently available: \(identity.displayName)")
                    continue
                }
                let registryID = claim.accessory.registryID
                guard claimedRegistryIDs.insert(registryID).inserted else {
                    logger.debug("Skipping duplicate match for saved USB device: \(identity.displayName)")
                    continue
                }
                do {
                    _ = try await attach(claim, replacing: savedIdentity)
                } catch {
                    claimedRegistryIDs.remove(registryID)
                    await releaseClaim(claim)
                    throw error
                }
            } catch {
                logger.debug("Failed to restore USB device \(identity.displayName): \(error.localizedDescription)")
            }
        }
        await notifyConnectedDevicesChanged()
    }

    func persistentIdentities() async -> [UTMRegistryEntry.AppleUSBDevice] {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                let identities = self.persistentConnections.sorted {
                    ($0.registryID ?? 0) < ($1.registryID ?? 0)
                }
                continuation.resume(returning: identities)
            }
        }
    }

    func usbController(_ usbController: VZUSBController, usbPassthroughDeviceDidDisconnect device: VZUSBPassthroughDevice) {
        Task { [weak self] in
            await self?.handleControllerDisconnect(usbController, device: device)
        }
    }

    private func handleControllerDisconnect(_ usbController: VZUSBController,
                                            device: VZUSBPassthroughDevice) async {
        await withOperationGate {
            let disconnected: ConnectionSnapshot? = await withCheckedContinuation { continuation in
                virtualMachineQueue.async {
                    guard self.virtualMachine?.usbControllers.first === usbController,
                          let registryID = self.connections.first(where: { $0.value.device === device })?.key,
                          let connection = self.connections[registryID],
                          self.pendingDetachClaims[registryID] != connection.claimID else {
                        continuation.resume(returning: nil)
                        return
                    }
                    self.connections.removeValue(forKey: registryID)
                    self.removePersistentConnection(registryID: registryID)
                    self.reservedClaims.removeValue(forKey: registryID)
                    continuation.resume(returning: ConnectionSnapshot(registryID: registryID,
                                                                        identity: connection.identity,
                                                                        claimID: connection.claimID))
                }
            }
            guard let disconnected = disconnected else {
                return
            }
            await broker.release(registryID: disconnected.registryID,
                                 ownerID: ownerID,
                                 claimID: disconnected.claimID)
            await notifyConnectedDevicesChanged()
        }
    }

    private func configure(virtualMachine: VZVirtualMachine) async throws -> [UInt64: UUID] {
        try await withCheckedThrowingContinuation { continuation in
            virtualMachineQueue.async {
                guard virtualMachine.state == .running else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                guard let usbController = virtualMachine.usbControllers.first else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.noUsbController)
                    return
                }
                if self.virtualMachine === virtualMachine {
                    usbController.delegate = self
                    continuation.resume(returning: [:])
                    return
                }
                self.virtualMachine?.usbControllers.first?.delegate = nil
                self.generation += 1
                self.claimSessionID = UUID()
                var staleClaims = self.connections.mapValues(\.claimID)
                staleClaims.merge(self.reservedClaims) { _, reservedClaimID in reservedClaimID }
                staleClaims.merge(self.pendingClaims) { _, pendingClaimID in pendingClaimID }
                self.connections.removeAll()
                self.reservedClaims.removeAll()
                self.pendingClaims.removeAll()
                self.pendingDetachClaims.removeAll()
                self.virtualMachine = virtualMachine
                self.isSuspended = true
                usbController.delegate = self
                continuation.resume(returning: staleClaims)
            }
        }
    }

    private func addObserver() async {
        await broker.addObserver(ownerID: ownerID) { [weak self] event in
            self?.enqueue(event: event)
        }
    }

    private func enqueue(event: UTMAppleUSBAccessoryEvent) {
        eventTaskLock.lock()
        let previousTask = eventTask
        eventTask = Task { [weak self] in
            await previousTask?.value
            await self?.handle(event: event)
        }
        eventTaskLock.unlock()
    }

    private func handle(event: UTMAppleUSBAccessoryEvent) async {
        await withOperationGate {
            await handleLocked(event: event)
        }
    }

    private func handleLocked(event: UTMAppleUSBAccessoryEvent) async {
        let state: UTMAppleUSBDevice.State
        if let previousOwnerID = event.previousOwnerID {
            state = previousOwnerID == ownerID ? .connected : .inUse
        } else {
            state = .available
        }
        switch event.kind {
        case .discovered:
            break
        case .removed:
            if await forgetConnection(registryID: event.registryID) {
                await notifyConnectedDevicesChanged()
            }
        }
        let device = UTMAppleUSBDevice(registryID: event.registryID,
                                       identity: event.identity,
                                       name: event.identity.displayName,
                                       state: state)
        await MainActor.run {
            switch event.kind {
            case .discovered:
                self.owner?.didDiscover(device)
            case .removed:
                self.owner?.didRemove(device)
            }
        }
    }

    private func attach(_ claim: UTMAppleUSBAccessoryClaim,
                        replacing savedIdentity: UTMRegistryEntry.AppleUSBDevice? = nil) async throws -> Bool {
        let registryID = claim.accessory.registryID
        return try await withCheckedThrowingContinuation { continuation in
            virtualMachineQueue.async {
                if let connection = self.connections[registryID] {
                    self.recordPersistentConnection(connection.identity, replacing: savedIdentity)
                    self.reservedClaims.removeValue(forKey: registryID)
                    continuation.resume(returning: false)
                    return
                }
                guard self.pendingClaims[registryID] == nil else {
                    continuation.resume(returning: false)
                    return
                }
                guard let usbController = self.virtualMachine?.usbControllers.first else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.noUsbController)
                    return
                }
                guard self.virtualMachine?.state == .running else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                let generation = self.generation
                self.pendingClaims[registryID] = claim.claimID
                do {
                    let configuration = VZUSBPassthroughDeviceConfiguration(device: claim.accessory)
                    let passthroughDevice = try VZUSBPassthroughDevice(configuration: configuration)
                    usbController.attach(device: passthroughDevice) { error in
                        guard self.pendingClaims[registryID] == claim.claimID else {
                            continuation.resume(throwing: UTMAppleUSBManagerError.deviceUnavailable)
                            return
                        }
                        self.pendingClaims.removeValue(forKey: registryID)
                        guard self.generation == generation else {
                            continuation.resume(throwing: UTMAppleUSBManagerError.deviceUnavailable)
                            return
                        }
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            self.connections[registryID] = Connection(identity: claim.identity,
                                                                      device: passthroughDevice,
                                                                      claimID: claim.claimID)
                            self.recordPersistentConnection(claim.identity, replacing: savedIdentity)
                            self.reservedClaims.removeValue(forKey: registryID)
                            continuation.resume(returning: true)
                        }
                    }
                } catch {
                    if self.pendingClaims[registryID] == claim.claimID {
                        self.pendingClaims.removeValue(forKey: registryID)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func detach(registryID: UInt64, retainingOwnership: Bool) async throws -> UTMRegistryEntry.AppleUSBDevice? {
        let snapshot: ConnectionSnapshot? = try await withCheckedThrowingContinuation { continuation in
            virtualMachineQueue.async {
                guard let connection = self.connections[registryID] else {
                    continuation.resume(returning: nil)
                    return
                }
                guard self.pendingDetachClaims[registryID] == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let usbController = self.virtualMachine?.usbControllers.first else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.noUsbController)
                    return
                }
                guard self.virtualMachine?.state == .running else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                let generation = self.generation
                self.pendingDetachClaims[registryID] = connection.claimID
                usbController.detach(device: connection.device) { error in
                    guard self.pendingDetachClaims[registryID] == connection.claimID else {
                        continuation.resume(throwing: UTMAppleUSBManagerError.deviceUnavailable)
                        return
                    }
                    self.pendingDetachClaims.removeValue(forKey: registryID)
                    guard self.generation == generation else {
                        continuation.resume(throwing: UTMAppleUSBManagerError.deviceUnavailable)
                        return
                    }
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        self.connections.removeValue(forKey: registryID)
                        if retainingOwnership {
                            self.reservedClaims[registryID] = connection.claimID
                        } else {
                            self.removePersistentConnection(registryID: registryID)
                        }
                        continuation.resume(returning: ConnectionSnapshot(registryID: registryID,
                                                                          identity: connection.identity,
                                                                          claimID: connection.claimID))
                    }
                }
            }
        }
        if !retainingOwnership, let snapshot = snapshot {
            await broker.release(registryID: registryID,
                                 ownerID: ownerID,
                                 claimID: snapshot.claimID)
        }
        return snapshot?.identity
    }

    private func connectionSnapshots() async -> [ConnectionSnapshot] {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                let snapshots = self.connections.map { registryID, connection in
                    ConnectionSnapshot(registryID: registryID,
                                       identity: connection.identity,
                                       claimID: connection.claimID)
                }.sorted { $0.registryID < $1.registryID }
                continuation.resume(returning: snapshots)
            }
        }
    }

    private func releaseClaim(_ claim: UTMAppleUSBAccessoryClaim) async {
        let shouldRelease: Bool = await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                let registryID = claim.accessory.registryID
                if self.connections[registryID]?.claimID == claim.claimID ||
                    self.pendingClaims[registryID] == claim.claimID {
                    continuation.resume(returning: false)
                    return
                }
                if self.reservedClaims[registryID] == claim.claimID {
                    self.reservedClaims.removeValue(forKey: registryID)
                }
                continuation.resume(returning: true)
            }
        }
        if shouldRelease {
            await broker.release(registryID: claim.accessory.registryID,
                                 ownerID: ownerID,
                                 claimID: claim.claimID)
        }
    }

    private func claimSessionIDSnapshot() async -> UUID {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                continuation.resume(returning: self.claimSessionID)
            }
        }
    }

    private func ensureVirtualMachineIsRunning() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            virtualMachineQueue.async {
                guard let virtualMachine = self.virtualMachine,
                      virtualMachine.state == .running,
                      !self.isSuspended else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                continuation.resume()
            }
        }
    }

    private func ensureCurrentVirtualMachineIsRunning(_ virtualMachine: VZVirtualMachine) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            virtualMachineQueue.async {
                guard self.virtualMachine === virtualMachine, virtualMachine.state == .running else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                continuation.resume()
            }
        }
    }

    private func isCurrentVirtualMachine(_ virtualMachine: VZVirtualMachine) async -> Bool {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                continuation.resume(returning: self.virtualMachine === virtualMachine)
            }
        }
    }

    private func setSuspended(_ isSuspended: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            virtualMachineQueue.async {
                guard let virtualMachine = self.virtualMachine,
                      virtualMachine.state == .running else {
                    continuation.resume(throwing: UTMAppleUSBManagerError.virtualMachineNotRunning)
                    return
                }
                self.isSuspended = isSuspended
                continuation.resume()
            }
        }
    }

    private func withOperationGate<T>(_ operation: () async throws -> T) async rethrows -> T {
        await operationGate.acquire()
        do {
            let result = try await operation()
            await operationGate.release()
            return result
        } catch {
            await operationGate.release()
            throw error
        }
    }

    private func connectedRegistryIDs() async -> Set<UInt64> {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                continuation.resume(returning: Set(self.connections.keys))
            }
        }
    }

    private func forgetConnection(registryID: UInt64) async -> Bool {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                self.connections.removeValue(forKey: registryID)
                self.reservedClaims.removeValue(forKey: registryID)
                self.pendingClaims.removeValue(forKey: registryID)
                self.pendingDetachClaims.removeValue(forKey: registryID)
                let wasPersistent = self.removePersistentConnection(registryID: registryID)
                continuation.resume(returning: wasPersistent)
            }
        }
    }

    private func setPersistentConnections(_ devices: [UTMRegistryEntry.AppleUSBDevice]) async {
        await withCheckedContinuation { continuation in
            virtualMachineQueue.async {
                self.persistentConnections = devices
                continuation.resume()
            }
        }
    }

    private func recordPersistentConnection(_ identity: UTMRegistryEntry.AppleUSBDevice,
                                            replacing savedIdentity: UTMRegistryEntry.AppleUSBDevice?) {
        if let savedIdentity = savedIdentity,
           let index = persistentConnections.firstIndex(of: savedIdentity) {
            persistentConnections[index] = identity
        } else if let registryID = identity.registryID,
                  let index = persistentConnections.firstIndex(where: { $0.registryID == registryID }) {
            persistentConnections[index] = identity
        } else if let index = persistentConnections.firstIndex(where: {
            $0.deviceDescriptorData == identity.deviceDescriptorData &&
                ($0.registryID == nil || $0.hostBootSessionID != currentHostBootSessionID)
        }) {
            persistentConnections[index] = identity
        } else {
            persistentConnections.append(identity)
        }
    }

    @discardableResult
    private func removePersistentConnection(registryID: UInt64) -> Bool {
        let oldCount = persistentConnections.count
        persistentConnections.removeAll { $0.registryID == registryID }
        return persistentConnections.count != oldCount
    }

    private func devicesForRestore(_ devices: [UTMRegistryEntry.AppleUSBDevice],
                                   using availableDevices: [UTMAppleUSBDevice]) -> [UTMRegistryEntry.AppleUSBDevice?] {
        var result = [UTMRegistryEntry.AppleUSBDevice?](repeating: nil, count: devices.count)
        var candidates = availableDevices.map(\.identity)
        var unresolvedIndices: [Int] = []
        for (index, device) in devices.enumerated() {
            guard device.hostBootSessionID == currentHostBootSessionID,
                  let registryID = device.registryID,
                  let candidateIndex = candidates.firstIndex(where: {
                      $0.registryID == registryID && $0.deviceDescriptorData == device.deviceDescriptorData
                  }) else {
                unresolvedIndices.append(index)
                continue
            }
            result[index] = candidates.remove(at: candidateIndex)
        }
        let groups = Dictionary(grouping: unresolvedIndices) { devices[$0].deviceDescriptorData }
        for (descriptor, indices) in groups {
            let matchingCandidates = candidates.filter { $0.deviceDescriptorData == descriptor }
            guard matchingCandidates.count == indices.count else {
                continue
            }
            for (index, candidate) in zip(indices, matchingCandidates) {
                result[index] = candidate
            }
            let registryIDs = Set(matchingCandidates.compactMap(\.registryID))
            candidates.removeAll { candidate in
                candidate.registryID.map(registryIDs.contains) ?? false
            }
        }
        return result
    }

    private func notifyConnectedDevicesChanged() async {
        let identities = (await persistentIdentities()).map(\.persisted)
        await MainActor.run {
            owner?.connectedDevicesDidChange(identities)
        }
    }
}

@available(macOS 27, *)
private func makeIdentity(for accessory: AAUSBAccessory) throws -> UTMRegistryEntry.AppleUSBDevice {
    let descriptor = accessory.deviceDescriptorData
    guard descriptor.count >= 18 else {
        throw UTMAppleUSBManagerError.invalidDeviceDescriptor
    }
    let bytes = [UInt8](descriptor)
    let vendorID = UInt16(bytes[8]) | UInt16(bytes[9]) << 8
    let productID = UInt16(bytes[10]) | UInt16(bytes[11]) << 8
    return UTMRegistryEntry.AppleUSBDevice(vendorID: vendorID,
                                           productID: productID,
                                           deviceClass: bytes[4],
                                           deviceSubclass: bytes[5],
                                           deviceProtocol: bytes[6],
                                           deviceDescriptorData: descriptor,
                                           registryID: accessory.registryID,
                                           hostBootSessionID: currentHostBootSessionID)
}

#endif

private extension UTMRegistryEntry.AppleUSBDevice {
    var persisted: Self {
        let canPersistRegistryID = hostBootSessionID != nil && hostBootSessionID == currentHostBootSessionID
        return Self(vendorID: vendorID,
                    productID: productID,
                    deviceClass: deviceClass,
                    deviceSubclass: deviceSubclass,
                    deviceProtocol: deviceProtocol,
                    deviceDescriptorData: deviceDescriptorData,
                    registryID: canPersistRegistryID ? registryID : nil,
                    hostBootSessionID: canPersistRegistryID ? hostBootSessionID : nil)
    }

    var displayName: String {
        String(format: NSLocalizedString("USB Device (%04X:%04X)", comment: "UTMAppleUSBManager"), Int(vendorID), Int(productID))
    }
}

private let currentHostBootSessionID: UUID? = {
    var size = 0
    guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
        return nil
    }
    var buffer = [UInt8](repeating: 0, count: size)
    let result = buffer.withUnsafeMutableBytes { bytes in
        sysctlbyname("kern.bootsessionuuid", bytes.baseAddress, &size, nil, 0)
    }
    guard result == 0,
          let value = String(bytes: buffer.prefix(while: { $0 != 0 }), encoding: .utf8) else {
        return nil
    }
    return UUID(uuidString: value)
}()
