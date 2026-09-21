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

import Foundation

@MainActor
@objc(UTMScriptingSnapshotImpl)
class UTMScriptingSnapshotImpl: NSObject, UTMScriptable {
    /// Read when the object is resolved, which happens anew for every event
    private var snapshot: UTMSnapshot
    /// Held strongly because a command runs after the accessor that made this object has returned
    @objc private(set) var parent: UTMScriptingVirtualMachineImpl

    private var vm: (any UTMVirtualMachine)! {
        parent.vm
    }

    init(snapshot: UTMSnapshot, parent: UTMScriptingVirtualMachineImpl) {
        self.snapshot = snapshot
        self.parent = parent
    }

    @objc var id: String {
        snapshot.id.uuidString
    }

    @objc var name: String {
        get {
            snapshot.title
        }

        set {
            do {
                snapshot = try UTMSnapshotService.renameSnapshot(snapshot.id, to: newValue, on: vm)
            } catch {
                let command = NSScriptCommand.current()
                command?.scriptErrorNumber = errOSAGeneralError
                command?.scriptErrorString = error.localizedDescription
            }
        }
    }

    @objc var creationDate: Date {
        snapshot.dateCreated
    }

    @objc var modificationDate: Date {
        snapshot.dateModified
    }

    @objc var size: Int {
        Int(snapshot.size)
    }

    @objc var includesRunningState: Bool {
        snapshot.hasState
    }

    @objc var isDataMissing: Bool {
        snapshot.isOrphaned
    }

    /// Identifier of the snapshot this one was based on, empty if it was not based on any
    @objc var basedOn: String {
        snapshot.parentID?.uuidString ?? ""
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let parentDescription = parent.classDescription as? NSScriptClassDescription else {
            return nil
        }
        return NSUniqueIDSpecifier(containerClassDescription: parentDescription,
                                   containerSpecifier: parent.objectSpecifier,
                                   key: "snapshots",
                                   uniqueID: id)
    }

    // MARK: - Commands

    @objc func restore(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            try await UTMSnapshotService.restoreSnapshot(snapshot.id, on: vm)
        }
    }

    @objc func overwrite(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            try await UTMSnapshotService.overwriteSnapshot(snapshot.id, on: vm)
        }
    }

    @objc func deleteSnapshot(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            try await UTMSnapshotService.deleteSnapshot(snapshot.id, on: vm)
        }
    }

    static func == (lhs: UTMScriptingSnapshotImpl, rhs: UTMScriptingSnapshotImpl) -> Bool {
        lhs.snapshot.id == rhs.snapshot.id && lhs.parent == rhs.parent
    }
}
