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
protocol UTMIntent: AppIntent {
    associatedtype T : IntentResult

    var data: UTMData { get }
    var vmEntity: UTMVirtualMachineEntity { get }
    func perform(with vm: any UTMVirtualMachine, boxed: VMData) async throws -> T
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
@available(*, deprecated)
extension UTMIntent {
    static var openAppWhenRun: Bool { true }
}

@available(iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26, *)
extension UTMIntent {
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension UTMIntent {
    @MainActor
    func perform() async throws -> T {
        guard let vm = data.virtualMachines.first(where: { $0.id == vmEntity.id }) else {
            throw UTMIntentError.virtualMachineNotFound
        }
        if !vm.isLoaded {
            do { try vm.load() } catch { throw UTMIntentError.localizedError(error) }
        }
        do {
            return try await perform(with: vm.wrapped!, boxed: vm)
        } catch {
            throw UTMIntentError.localizedError(error)
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
enum UTMIntentError: Error, CustomLocalizedStringResourceConvertible {
    case localizedError(Error)
    case virtualMachineNotFound
    case unsupportedBackend
    case inputHandlerNotAvailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .localizedError(let wrapped):
            return "\(wrapped.localizedDescription)"
        case .virtualMachineNotFound:
            return "Virtual machine not found."
        case .unsupportedBackend:
            return "Operation not supported by the backend."
        case .inputHandlerNotAvailable:
            return "Input handler not available."
        }
    }
}
