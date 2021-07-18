//
// Copyright © 2021 osy. All rights reserved.
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
import SwiftUI

enum VMWizardPage: Int, Identifiable {
    var id: Int {
        return self.rawValue
    }
    
    case start
    case operatingSystem
    case macOSBoot
    case linuxBoot
    case windowsBoot
    case otherBoot
    case hardware
    case drives
    case sharing
    case summary
}

enum VMWizardOS: Int, Identifiable {
    var id: Int {
        return self.rawValue
    }
    
    case other
    case macOS
    case linux
    case windows
}

@available(iOS 14, macOS 11, *)
class VMWizardState: ObservableObject {
    private let bytesInMib = 1048576
    
    @Published var slide: AnyTransition = .identity
    @Published var currentPage: VMWizardPage = .start
    @Published var alertMessage: AlertMessage?
    @Published var isBusy: Bool = false
    @Published var useVirtualization: Bool = false {
        didSet {
            if !useVirtualization {
                useAppleVirtualization = false
            }
        }
    }
    @Published var useAppleVirtualization: Bool = false {
        didSet {
            if useAppleVirtualization {
                useLinuxKernel = true
            }
        }
    }
    @Published var operatingSystem: VMWizardOS = .other
    #if os(macOS) && arch(arm64)
    @Published var macPlatform: MacPlatform?
    @Published var macRecoveryIpswURL: URL?
    #endif
    @Published var isSkipBootImage: Bool = false
    @Published var bootImageURL: URL?
    @Published var useLinuxKernel: Bool = false
    @Published var linuxKernelURL: URL?
    @Published var linuxInitialRamdiskURL: URL?
    @Published var linuxRootImageURL: URL?
    @Published var linuxBootArguments: String = ""
    @Published var systemArchitecture: String?
    @Published var systemTarget: String?
    #if os(macOS)
    @Published var systemMemory: UInt64 = 4096 * 1048576
    @Published var storageSizeGib: Int = 64
    #else
    @Published var systemMemory: UInt64 = 512 * 1048576
    @Published var storageSizeGib: Int = 8
    #endif
    @Published var systemCpuCount: Int = 1
    
    var hasNextButton: Bool {
        switch currentPage {
        case .start:
            return false
        case .operatingSystem:
            return false
        default:
            return true
        }
    }
    
    var slideIn: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .opacity)
    }
    
    var slideOut: AnyTransition {
        .asymmetric(insertion: .move(edge: .leading), removal: .opacity)
    }
    
    func next() {
        var nextPage = currentPage
        switch currentPage {
        case .start:
            nextPage = .operatingSystem
        case .operatingSystem:
            switch operatingSystem {
            case .other:
                nextPage = .otherBoot
            case .macOS:
                nextPage = .macOSBoot
            case .linux:
                nextPage = .linuxBoot
            case .windows:
                nextPage = .windowsBoot
            }
        case .otherBoot:
            guard isSkipBootImage || bootImageURL != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                return
            }
            nextPage = .hardware
        case .macOSBoot:
            #if os(macOS) && arch(arm64)
            guard macPlatform != nil && macRecoveryIpswURL != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select an IPSW file.", comment: "VMWizardState"))
                return
            }
            nextPage = .hardware
            #endif
        case .linuxBoot:
            if useLinuxKernel {
                guard linuxKernelURL != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a kernel file.", comment: "VMWizardState"))
                    return
                }
            } else {
                guard bootImageURL != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                    return
                }
            }
            nextPage = .hardware
        case .windowsBoot:
            guard bootImageURL != nil else {
                alertMessage = AlertMessage(NSLocalizedString("Please select a boot image.", comment: "VMWizardState"))
                return
            }
            nextPage = .hardware
        case .hardware:
            if !useVirtualization {
                guard systemArchitecture != nil && systemTarget != nil else {
                    alertMessage = AlertMessage(NSLocalizedString("Please select a system to emulate.", comment: "VMWizardState"))
                    return
                }
            }
            nextPage = .drives
            #if arch(arm64)
            if operatingSystem == .windows && useVirtualization {
                nextPage = .sharing
            }
            #endif
        case .drives:
            nextPage = .sharing
        case .sharing:
            nextPage = .summary
        case .summary:
            save()
        }
        slide = slideIn
        withAnimation {
            currentPage = nextPage
        }
    }
    
    func back() {
        var previousPage = currentPage
        switch currentPage {
        case .start:
            break
        case .operatingSystem:
            previousPage = .start
        case .otherBoot:
            previousPage = .operatingSystem
        case .macOSBoot:
            previousPage = .operatingSystem
        case .linuxBoot:
            previousPage = .operatingSystem
        case .windowsBoot:
            previousPage = .operatingSystem
        case .hardware:
            switch operatingSystem {
            case .other:
                previousPage = .otherBoot
            case .macOS:
                previousPage = .macOSBoot
            case .linux:
                previousPage = .linuxBoot
            case .windows:
                previousPage = .windowsBoot
            }
        case .drives:
            previousPage = .hardware
        case .sharing:
            previousPage = .drives
            #if arch(arm64)
            if operatingSystem == .windows && useVirtualization {
                previousPage = .hardware // skip drives when using Windows ARM
            }
            #endif
        case .summary:
            previousPage = .sharing
        }
        slide = slideOut
        withAnimation {
            currentPage = previousPage
        }
    }
    
    func save() {
        
    }
    
    func busyWork(_ work: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            self.isBusy = true
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            }
            do {
                try work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    
    @available(iOS 15, macOS 12, *)
    func busyWorkAsync(_ work: @escaping () async throws -> Void) {
        Task(priority: .userInitiated) {
            DispatchQueue.main.async {
                self.isBusy = true
            }
            defer {
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            }
            do {
                try await work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
}
