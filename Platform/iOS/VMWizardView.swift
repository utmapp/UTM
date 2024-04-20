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

import SwiftUI

struct VMWizardView: View {
    @StateObject var wizardState = VMWizardState()
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        if #available(iOS 16, visionOS 1.0, *) {
            WizardNavigationView(wizardState: wizardState) {
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            NavigationView {
                WizardWrapper(page: .start, wizardState: wizardState) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationViewStyle(.stack)
            .alert(item: $wizardState.alertMessage) { msg in
                Alert(title: Text(msg.message))
            }
        }
    }
}

fileprivate struct WizardToolbar: ViewModifier {
    @ObservedObject var wizardState: VMWizardState
    let onDismiss: () -> Void
    @EnvironmentObject private var data: UTMData

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if wizardState.currentPage == .start {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if wizardState.hasNextButton {
                    Button("Continue") {
                        wizardState.next()
                    }
                } else if wizardState.currentPage == .summary {
                    Button("Save") {
                        onDismiss()
                        data.busyWorkAsync {
                            let config = try await wizardState.generateConfig()
                            if let qemuConfig = config as? UTMQemuConfiguration {
                                _ = try await data.create(config: qemuConfig)
                                if #available(iOS 15, *) {
                                    // This is broken on iOS 14
                                    await MainActor.run {
                                        qemuConfig.qemu.isGuestToolsInstallRequested = wizardState.isGuestToolsInstallRequested
                                    }
                                }
                            } else {
                                fatalError("Invalid configuration type.")
                            }
                            if await wizardState.isOpenSettingsAfterCreation {
                                await data.showSettingsForCurrentVM()
                            }
                        }
                    }
                }
            }
        }
    }
}

@available(iOS, deprecated: 17, message: "Use WizardViewWrapper")
@available(visionOS, deprecated: 1, message: "Use WizardViewWrapper")
fileprivate struct WizardWrapper: View {
    let page: VMWizardPage
    @ObservedObject var wizardState: VMWizardState
    @State private var nextPage: VMWizardPage?
    let onDismiss: () -> Void
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        VStack {
            WizardViewWrapper(page: page, wizardState: wizardState)
            NavigationLink(destination: WizardWrapper(page: .start, wizardState: wizardState, onDismiss: onDismiss), tag: .start, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .operatingSystem, wizardState: wizardState, onDismiss: onDismiss), tag: .operatingSystem, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .linuxBoot, wizardState: wizardState, onDismiss: onDismiss), tag: .linuxBoot, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .windowsBoot, wizardState: wizardState, onDismiss: onDismiss), tag: .windowsBoot, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .otherBoot, wizardState: wizardState, onDismiss: onDismiss), tag: .otherBoot, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .hardware, wizardState: wizardState, onDismiss: onDismiss), tag: .hardware, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .drives, wizardState: wizardState, onDismiss: onDismiss), tag: .drives, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .sharing, wizardState: wizardState, onDismiss: onDismiss), tag: .sharing, selection: $nextPage) {}
            NavigationLink(destination: WizardWrapper(page: .summary, wizardState: wizardState, onDismiss: onDismiss), tag: .summary, selection: $nextPage) {}
        }
        .listStyle(.insetGrouped) // needed for iOS 14
        .textFieldStyle(.roundedBorder)
        .modifier(WizardToolbar(wizardState: wizardState, onDismiss: onDismiss))
        .onChange(of: nextPage) { newPage in
            if newPage == nil {
                wizardState.currentPage = page
                wizardState.nextPageBinding = $nextPage
            }
        }
        .onAppear {
            wizardState.currentPage = page
            wizardState.nextPageBinding = $nextPage
        }
        .disabled(wizardState.isBusy)
    }
}

@available(iOS 16, visionOS 1.0, *)
fileprivate struct WizardNavigationView: View {
    @StateObject var wizardState = VMWizardState()
    let onDismiss: () -> Void
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    @State private var navigationPath: NavigationPath = .init()
    @State private var previousPage: VMWizardPage?
    @State private var isAlertShown: Bool = false
    
    var body: some View {
        NavigationStack(path: $wizardState.pageHistory) {
            WizardViewWrapper(page: .start, wizardState: wizardState)
                .modifier(WizardToolbar(wizardState: wizardState, onDismiss: onDismiss))
                .navigationDestination(for: VMWizardPage.self) { page in
                    WizardViewWrapper(page: page, wizardState: wizardState)
                        .modifier(WizardToolbar(wizardState: wizardState, onDismiss: onDismiss))
                }
                .textFieldStyle(.roundedBorder)
                .disabled(wizardState.isBusy)
        }
        .alert("Error", isPresented: $isAlertShown) {
            Button("OK", role: .cancel) {
                wizardState.alertMessage = nil
            }
        } message: {
            Text(wizardState.alertMessage?.message ?? "")
        }
        .onChange(of: wizardState.alertMessage?.message) { newValue in
            isAlertShown = newValue != nil
        }
    }
}

fileprivate struct WizardViewWrapper: View {
    let page: VMWizardPage
    @ObservedObject var wizardState: VMWizardState

    var body: some View {
        switch page {
        case .start:
            #if WITH_QEMU_TCI
            VMWizardStartViewTCI(wizardState: wizardState)
            #else
            VMWizardStartView(wizardState: wizardState)
            #endif
        case .operatingSystem:
            VMWizardOSView(wizardState: wizardState)
        case .macOSBoot:
            EmptyView()
        case .linuxBoot:
            VMWizardOSLinuxView(wizardState: wizardState)
        case .windowsBoot:
            VMWizardOSWindowsView(wizardState: wizardState)
        case .otherBoot:
            VMWizardOSOtherView(wizardState: wizardState)
        case .hardware:
            VMWizardHardwareView(wizardState: wizardState)
        case .drives:
            VMWizardDrivesView(wizardState: wizardState)
        case .sharing:
            VMWizardSharingView(wizardState: wizardState)
        case .summary:
            VMWizardSummaryView(wizardState: wizardState)
        }
    }
}

struct VMWizardView_Previews: PreviewProvider {
    static var previews: some View {
        VMWizardView()
    }
}
