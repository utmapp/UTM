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
#if os(macOS)
import AppKit
#endif

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMStatusActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Get Virtual Machine Status"
    static let description = IntentDescription("Get the status of a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$vmEntity) status")
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some ReturnsValue<UTMVirtualMachineState> {
        return .result(value: vm.state)
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMStartActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Start Virtual Machine"
    static let description = IntentDescription("Start a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$vmEntity)") {
            \.$isRecovery
            \.$isDisposible
        }
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "Recovery", description: "Boot into recovery mode. Only supported on Apple Virtualization backend.", default: false)
    var isRecovery: Bool

    @Parameter(title: "Disposible", description: "Do not save any changes to disk. Only supported on QEMU backend.", default: false)
    var isDisposible: Bool

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        var options = UTMVirtualMachineStartOptions()
        if isRecovery {
            #if os(macOS)
            guard vm is UTMAppleVirtualMachine else {
                throw UTMIntentError.unsupportedBackend
            }
            options.insert(.bootRecovery)
            #else
            throw UTMIntentError.unsupportedBackend
            #endif
        }
        if isDisposible {
            guard vm is UTMQemuVirtualMachine else {
                throw UTMIntentError.unsupportedBackend
            }
            options.insert(.bootDisposibleMode)
        }
        #if os(macOS)
        // Ensure the app comes to the foreground before presenting VM UI
        NSApp.activate(ignoringOtherApps: true)
        #endif
        data.run(vm: boxed, options: options)
        // For platforms that support foreground continuation, request it (no-op on older SDKs).
        if !vm.isHeadless {
            if #available(iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26, *), systemContext.currentMode.canContinueInForeground {
                try await continueInForeground(alwaysConfirm: false)
            }
        }
        return .result()
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMStopActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Stop Virtual Machine"
    static let description = IntentDescription("Stop a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Stop \(\.$vmEntity) by \(\.$method)")
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "Stop Method", description: "Intensity of the stop action.", default: .force)
    var method: UTMVirtualMachineStopMethod

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        try await vm.stop(usingMethod: method)
        return .result()
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension UTMVirtualMachineStopMethod: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(
            name: "Stop Method"
        )

    static let caseDisplayRepresentations: [UTMVirtualMachineStopMethod: DisplayRepresentation] = [
        .request: DisplayRepresentation(title: "Request", subtitle: "Sends power down request to the guest. This simulates pressing the power button on a PC."),
        .force: DisplayRepresentation(title: "Force", subtitle: "Tells the VM process to shut down with risk of data corruption. This simulates holding down the power button on a PC."),
        .kill: DisplayRepresentation(title: "Killing", subtitle: "Force kill the VM process with high risk of data corruption."),
    ]
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMPauseActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Pause Virtual Machine"
    static let description = IntentDescription("Pause a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Pause \(\.$vmEntity)") {
            \.$isSaveState
        }
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @Parameter(title: "Save State", description: "Create a snapshot of the virtual machine state.", default: false)
    var isSaveState: Bool

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        try await vm.pause()
        if isSaveState {
            try await vm.save()
        }
        return .result()
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMResumeActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Resume Virtual Machine"
    static let description = IntentDescription("Resume a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Resume \(\.$vmEntity)")
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        try await vm.resume()
        if !vm.isHeadless {
            if #available(iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26, *), systemContext.currentMode.canContinueInForeground {
                try await continueInForeground(alwaysConfirm: false)
            }
        }
        return .result()
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMRestartActionIntent: AppIntent, UTMIntent {
    static let title: LocalizedStringResource = "Restart Virtual Machine"
    static let description = IntentDescription("Restart a virtual machine.")
    static var parameterSummary: some ParameterSummary {
        Summary("Restart \(\.$vmEntity)")
    }

    @Dependency
    var data: UTMData

    @Parameter(title: "Virtual Machine", requestValueDialog: "Select a virtual machine")
    var vmEntity: UTMVirtualMachineEntity

    @MainActor
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> some IntentResult {
        try await vm.restart()
        if !vm.isHeadless {
            if #available(iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26, *), systemContext.currentMode.canContinueInForeground {
                try await continueInForeground(alwaysConfirm: false)
            }
        }
        return .result()
    }
}
