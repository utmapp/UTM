//
// Copyright © 2025 osy. All rights reserved.
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

import AppIntents

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMVirtualMachineEntity: AppEntity {
    static let defaultQuery = UTMVirtualMachineEntityQuery()

    let id: UUID

    var iconURL: URL?

    @Property(title: "Name")
    var name: String

    @Property(title: "Description")
    var description: String

    @Property(title: "Status")
    var state: UTMVirtualMachineState

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "Virtual Machine",
            numericFormat: "\(placeholder: .int) virtual machines"
        )
    }

    var displayRepresentation: DisplayRepresentation {
        var display = DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(description)"
        )
        if let iconURL = iconURL {
            display.image = DisplayRepresentation.Image(url: iconURL)
        }
        return display
    }

    @MainActor
    init(from vm: VMData) {
        id = vm.id
        name = vm.detailsTitleLabel
        description = vm.detailsSubtitleLabel
        state = vm.state
        iconURL = vm.detailsIconUrl
    }
}


@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension UTMVirtualMachineState: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(
            name: "Status"
        )

    static let caseDisplayRepresentations: [UTMVirtualMachineState: DisplayRepresentation] = [
        .stopped: DisplayRepresentation(title: "Stopped"),
        .starting: DisplayRepresentation(title: "Starting"),
        .started: DisplayRepresentation(title: "Started"),
        .pausing: DisplayRepresentation(title: "Pausing"),
        .paused: DisplayRepresentation(title: "Paused"),
        .resuming: DisplayRepresentation(title: "Resuming"),
        .saving: DisplayRepresentation(title: "Saving"),
        .restoring: DisplayRepresentation(title: "Restoring"),
        .stopping: DisplayRepresentation(title: "Stopping"),
    ]
}
