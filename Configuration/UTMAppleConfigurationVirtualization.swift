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
import Virtualization

/// Device settings.
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
struct UTMAppleConfigurationVirtualization: Codable {
    enum PointerDevice: String, CaseIterable, QEMUConstant {
        case disabled = "Disabled"
        case mouse = "Mouse"
        case trackpad = "Trackpad"
        
        var prettyValue: String {
            switch self {
            case .disabled: return NSLocalizedString("Disabled", comment: "UTMAppleConfigurationDevices")
            case .mouse: return NSLocalizedString("Generic Mouse", comment: "UTMAppleConfigurationDevices")
            case .trackpad: return NSLocalizedString("Mac Trackpad (macOS 13+)", comment: "UTMAppleConfigurationDevices")
            }
        }
    }
    
    enum KeyboardDevice: String, CaseIterable, QEMUConstant {
        case disabled = "Disabled"
        case generic = "Generic"
        case mac = "Mac"
        
        var prettyValue: String {
            switch self {
            case .disabled: return NSLocalizedString("Disabled", comment: "UTMAppleConfigurationDevices")
            case .generic: return NSLocalizedString("Generic USB", comment: "UTMAppleConfigurationDevices")
            case .mac: return NSLocalizedString("Mac Keyboard (macOS 14+)", comment: "UTMAppleConfigurationDevices")
            }
        }
    }
    
    var hasAudio: Bool = false
    
    var hasBalloon: Bool = true
    
    var hasEntropy: Bool = true
    
    var keyboard: KeyboardDevice = .disabled
    
    var pointer: PointerDevice = .disabled
    
    var hasRosetta: Bool?
    
    var hasClipboardSharing: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case hasAudio = "Audio"
        case hasBalloon = "Balloon"
        case hasEntropy = "Entropy"
        case keyboard = "Keyboard"
        case pointer = "Pointer"
        case hasTrackpad = "Trackpad"
        case rosetta = "Rosetta"
        case hasClipboardSharing = "ClipboardSharing"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hasAudio = try values.decode(Bool.self, forKey: .hasAudio)
        hasBalloon = try values.decode(Bool.self, forKey: .hasBalloon)
        hasEntropy = try values.decode(Bool.self, forKey: .hasEntropy)
        if let hasKeyboard = try? values.decode(Bool.self, forKey: .keyboard) {
            keyboard = hasKeyboard ? .generic : .disabled
        } else {
            keyboard = try values.decode(KeyboardDevice.self, forKey: .keyboard)
        }
        if let hasPointer = try? values.decode(Bool.self, forKey: .pointer) {
            let hasTrackpad = try values.decodeIfPresent(Bool.self, forKey: .hasTrackpad) ?? false
            pointer = hasTrackpad ? .trackpad : hasPointer ? .mouse : .disabled
        } else {
            pointer = try values.decode(PointerDevice.self, forKey: .pointer)
        }
        if #available(macOS 13, *) {
            hasRosetta = try values.decodeIfPresent(Bool.self, forKey: .rosetta)
            hasClipboardSharing = try values.decodeIfPresent(Bool.self, forKey: .hasClipboardSharing) ?? false
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasAudio, forKey: .hasAudio)
        try container.encode(hasBalloon, forKey: .hasBalloon)
        try container.encode(hasEntropy, forKey: .hasEntropy)
        try container.encode(keyboard, forKey: .keyboard)
        try container.encode(pointer, forKey: .pointer)
        try container.encodeIfPresent(hasRosetta, forKey: .rosetta)
        try container.encode(hasClipboardSharing, forKey: .hasClipboardSharing)
    }
}

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationVirtualization {
    init(migrating oldConfig: UTMLegacyAppleConfiguration) {
        self.init()
        hasBalloon = oldConfig.isBalloonEnabled
        hasEntropy = oldConfig.isEntropyEnabled
        if #available(macOS 12, *) {
            hasAudio = oldConfig.isAudioEnabled
            keyboard = oldConfig.isKeyboardEnabled ? .generic : .disabled
            pointer = oldConfig.isPointingEnabled ? .mouse : .disabled
        }
    }
}

// MARK: - Creating Apple config

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationVirtualization {
    func fillVZConfiguration(_ vzconfig: VZVirtualMachineConfiguration, isMacOSGuest: Bool = false) throws {
        if hasBalloon && !isMacOSGuest {
            vzconfig.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        }
        if hasEntropy {
            vzconfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        }
        if #available(macOS 12, *) {
            if hasAudio {
                let audioInputConfiguration = VZVirtioSoundDeviceConfiguration()
                let audioInput = VZVirtioSoundDeviceInputStreamConfiguration()
                audioInput.source = VZHostAudioInputStreamSource()
                audioInputConfiguration.streams = [audioInput]
                let audioOutputConfiguration = VZVirtioSoundDeviceConfiguration()
                let audioOutput = VZVirtioSoundDeviceOutputStreamConfiguration()
                audioOutput.sink = VZHostAudioOutputStreamSink()
                audioOutputConfiguration.streams = [audioOutput]
                vzconfig.audioDevices = [audioInputConfiguration, audioOutputConfiguration]
            }
            if keyboard != .disabled {
                vzconfig.keyboards = [VZUSBKeyboardConfiguration()]
                #if arch(arm64)
                if #available(macOS 14, *), isMacOSGuest && keyboard == .mac {
                    vzconfig.keyboards = [VZMacKeyboardConfiguration()]
                }
                #endif
            }
            if pointer != .disabled {
                vzconfig.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
                #if arch(arm64)
                if #available(macOS 13, *), isMacOSGuest && pointer == .trackpad {
                    // replace with trackpad device
                    vzconfig.pointingDevices = [VZMacTrackpadConfiguration()]
                }
                #endif
            }
        } else {
            if hasAudio || keyboard != .disabled || pointer != .disabled {
                throw UTMAppleConfigurationError.featureNotSupported
            }
        }
        if #available(macOS 13, *) {
            #if arch(arm64)
            if hasRosetta == true {
                let rosettaDirectoryShare = try VZLinuxRosettaDirectoryShare()
                if #available(macOS 14, *) {
                    // enable cache if possible
                    try? rosettaDirectoryShare.setCachingOptions(.defaultUnixSocket)
                }
                let fileSystemDevice = VZVirtioFileSystemDeviceConfiguration(tag: "rosetta")
                fileSystemDevice.share = rosettaDirectoryShare
                vzconfig.directorySharingDevices.append(fileSystemDevice)
            }
            #else
            if hasRosetta == true {
                throw UTMAppleConfigurationError.rosettaNotSupported
            }
            #endif
            if hasClipboardSharing {
                let spiceClipboardAgent = VZSpiceAgentPortAttachment()
                spiceClipboardAgent.sharesClipboard = true
                let consolePort = VZVirtioConsolePortConfiguration()
                consolePort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
                consolePort.attachment = spiceClipboardAgent
                consolePort.isConsole = false
                let consoleDevice = VZVirtioConsoleDeviceConfiguration()
                consoleDevice.ports[0] = consolePort
                vzconfig.consoleDevices.append(consoleDevice)
            }
        } else {
            if hasRosetta == true || hasClipboardSharing {
                throw UTMAppleConfigurationError.featureNotSupported
            }
        }
    }
}

// MARK: prepare save
extension UTMAppleConfigurationVirtualization {
    func prepareSave(for packageURL: URL) async throws {
        if #available(macOS 13, *), hasRosetta == true {
            try await installRosetta()
        }
    }
    
    @available(macOS 13, *)
    private func installRosetta() async throws {
        #if arch(arm64)
        let rosettaAvailability = VZLinuxRosettaDirectoryShare.availability
        if rosettaAvailability == .notSupported {
            throw UTMAppleConfigurationError.rosettaNotSupported
        } else if rosettaAvailability == .notInstalled {
            try await VZLinuxRosettaDirectoryShare.installRosetta()
        }
        #else
        throw UTMAppleConfigurationError.rosettaNotSupported
        #endif
    }
}
