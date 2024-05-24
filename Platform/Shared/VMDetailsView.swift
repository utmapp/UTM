//
// Copyright © 2020 osy. All rights reserved.
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

struct VMDetailsView: View {
    @ObservedObject var vm: VMData
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    private var regularScreenSizeClass: Bool {
        horizontalSizeClass == .regular
    }
    #else
    private let regularScreenSizeClass: Bool = true
    #endif

    @State private var size: Int64 = 0

    private var sizeLabel: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
    }
    
    var body: some View {
        if vm.isDeleted {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("This virtual machine has been removed.")
                        .font(.headline)
                    Spacer()
                }
                Spacer()
            }
        } else {
            ScrollView {
                Screenshot(vm: vm, large: regularScreenSizeClass)
                let notes = vm.detailsNotes ?? ""
                if regularScreenSizeClass && !notes.isEmpty {
                    HStack(alignment: .top) {
                        Details(vm: vm, sizeLabel: sizeLabel)
                            .frame(maxWidth: .infinity)
                        Text(notes)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding([.leading, .trailing])
                    }.padding([.leading, .trailing])
                    #if os(macOS)
                    if let appleVM = vm.wrapped as? UTMAppleVirtualMachine {
                        VMAppleRemovableDrivesView(vm: vm, config: appleVM.config, registryEntry: appleVM.registryEntry)
                            .padding([.leading, .trailing, .bottom])
                    } else if let qemuVM = vm.wrapped as? UTMQemuVirtualMachine {
                        VMRemovableDrivesView(vm: vm, config: qemuVM.config)
                            .padding([.leading, .trailing, .bottom])
                    }
                    #else
                    let qemuConfig = vm.config as! UTMQemuConfiguration
                    VMRemovableDrivesView(vm: vm, config: qemuConfig)
                        .padding([.leading, .trailing, .bottom])
                    #endif
                } else {
                    VStack {
                        Details(vm: vm, sizeLabel: sizeLabel)
                        if !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if os(macOS)
                        if let appleVM = vm.wrapped as? UTMAppleVirtualMachine {
                            VMAppleRemovableDrivesView(vm: vm, config: appleVM.config, registryEntry: appleVM.registryEntry)
                        } else if let qemuVM = vm.wrapped as? UTMQemuVirtualMachine {
                            VMRemovableDrivesView(vm: vm, config: qemuVM.config)
                        }
                        #else
                        let qemuConfig = vm.config as! UTMQemuConfiguration
                        VMRemovableDrivesView(vm: vm, config: qemuConfig)
                        #endif
                    }.padding([.leading, .trailing, .bottom])
                }
            }.labelStyle(DetailsLabelStyle())
            .modifier(VMOptionalNavigationTitleModifier(vm: vm))
            .modifier(VMToolbarModifier(vm: vm, bottom: !regularScreenSizeClass))
            .sheet(isPresented: $data.showSettingsModal) {
                if let qemuConfig = vm.config as? UTMQemuConfiguration {
                    VMSettingsView(vm: vm, config: qemuConfig)
                        .environmentObject(data)
                }
                #if os(macOS)
                if let appleConfig = vm.config as? UTMAppleConfiguration {
                    VMSettingsView(vm: vm, config: appleConfig)
                        .environmentObject(data)
                }
                #endif
            }
            .taskOnAppear(id: vm.id) {
                size = await data.computeSize(for: vm)
                #if WITH_REMOTE
                if let vm = vm.wrapped as? UTMRemoteSpiceVirtualMachine {
                    await vm.loadScreenshotFromServer()
                }
                #endif
            }
        }
    }
}

private extension View {
    func taskOnAppear<T>(id value: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable @MainActor () async -> Void) -> some View where T : Equatable & Hashable {
        #if os(visionOS) // FIXME: visionOS crashes with task()
        self.onAppear {
            Task(priority: priority, operation: action)
        }.id(value)
        #else
        if #available(macOS 12, iOS 15, *) {
            return self.task(id: value, priority: priority, action)
        } else {
            return self.onAppear {
                Task(priority: priority, operation: action)
            }.id(value)
        }
        #endif
    }
}

/// Returns just the content under macOS but adds the title on iOS. #3099
private struct VMOptionalNavigationTitleModifier: ViewModifier {
    @ObservedObject var vm: VMData
    
    func body(content: Content) -> some View {
        #if os(macOS)
        return content.navigationSubtitle(vm.detailsTitleLabel)
        #else
        return content.navigationTitle(vm.detailsTitleLabel)
        #endif
    }
}

struct Screenshot: View {
    @ObservedObject var vm: VMData
    let large: Bool
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            if let screenshotImage = vm.screenshotImage {
                #if os(macOS)
                Image(nsImage: screenshotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: screenshotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            }
            Rectangle()
                .fill(Color(red: 230/255, green: 229/255, blue: 235/255))
                .blendMode(.hardLight)
            #if os(visionOS)
                .overlay {
                    if vm.isStopped || vm.isTakeoverAllowed {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                    }
                }
                .hoverEffect()
                .onTapGesture {
                    data.run(vm: vm)
                }
            #endif
            if vm.isBusy {
                Spinner(size: .large)
            } else if vm.isStopped || vm.isTakeoverAllowed {
                #if !os(visionOS)
                Button(action: { data.run(vm: vm) }, label: {
                    Label("Run", systemImage: "play.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(Font.system(size: 96))
                        .foregroundColor(Color.black)
                }).buttonStyle(.plain)
                #endif
            }
        }.aspectRatio(CGSize(width: 16, height: 9), contentMode: large ? .fill : .fit)
        #if os(visionOS)
        .frame(maxWidth: 500)
        #endif
    }
}

struct Details: View {
    @ObservedObject var vm: VMData
    let sizeLabel: String
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        VStack {
            if vm.isShortcut {
                HStack {
                    plainLabel("Path", systemImage: "folder")
                    Spacer()
                    Text(vm.pathUrl.path)
                        .foregroundColor(.secondary)
                }
            }
            HStack {
                plainLabel("Status", systemImage: "info.circle")
                Spacer()
                Text(vm.stateLabel)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Architecture", systemImage: "cpu")
                Spacer()
                Text(vm.detailsSystemArchitectureLabel)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Machine", systemImage: "desktopcomputer")
                Spacer()
                Text(vm.detailsSystemTargetLabel)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Memory", systemImage: "memorychip")
                Spacer()
                Text(vm.detailsSystemMemoryLabel)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Size", systemImage: "internaldrive")
                Spacer()
                Text(sizeLabel)
                    .foregroundColor(.secondary)
            }
            #if os(macOS)
            if let appleConfig = vm.config as? UTMAppleConfiguration {
                ForEach(appleConfig.serials) { serial in
                    if serial.mode == .ptty {
                        HStack {
                            plainLabel("Serial (TTY)", systemImage: "phone.connection")
                            Spacer()
                            OptionalSelectableText(serial.interface?.name)
                        }
                    }
                }
            }
            #endif
            if let qemuConfig = vm.config as? UTMQemuConfiguration {
                ForEach(qemuConfig.serials) { serial in
                    if serial.mode == .tcpClient {
                        HStack {
                            plainLabel("Serial (Client)", systemImage: "network")
                            Spacer()
                            let address = "\(serial.tcpHostAddress ?? "example.com"):\(serial.tcpPort ?? 1234)"
                            OptionalSelectableText(vm.state == .started ? address : nil)
                        }
                    } else if serial.mode == .tcpServer {
                        HStack {
                            plainLabel("Serial (Server)", systemImage: "network")
                            Spacer()
                            let address = "\(serial.tcpPort ?? 1234)"
                            OptionalSelectableText(vm.state == .started ? address : nil)
                        }
                    }
                    #if os(macOS)
                    if serial.mode == .ptty {
                        HStack {
                            plainLabel("Serial (TTY)", systemImage: "phone.connection")
                            Spacer()
                            OptionalSelectableText(serial.pttyDevice?.path)
                        }
                    }
                    #endif
                }
            }
        }.lineLimit(1)
        .truncationMode(.tail)
    }
    
    private func plainLabel(_ text: String, systemImage: String) -> some View {
        return Label {
            Text(LocalizedStringKey(text))
        } icon: {
            Image(systemName: systemImage).foregroundColor(.primary)
        }
    }
}

struct DetailsLabelStyle: LabelStyle {
    var color: Color = .accentColor
    
    func makeBody(configuration: Configuration) -> some View {
        Label(
            title: { configuration.title.font(.headline) },
            icon: {
                ZStack(alignment: .center) {
                    Rectangle()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.clear)
                    configuration.icon.foregroundColor(color)
                }
            })
    }
}

private struct OptionalSelectableText: View {
    var content: String?
    
    init(_ content: String?) {
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 15, macOS 12, *) {
            (content.map { Text($0) } ?? Text("Inactive", comment: "VMDetailsView"))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        } else {
            (content.map { Text($0) } ?? Text("Inactive", comment: "VMDetailsView"))
                .foregroundColor(.secondary)
        }
    }
}

struct VMDetailsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMDetailsView(vm: VMData(from: .empty))
        .onAppear {
            config.sharing.directoryShareMode = .webdav
            var drive = UTMQemuConfigurationDrive()
            drive.imageType = .disk
            drive.interface = .ide
            config.drives.append(drive)
            drive.interface = .scsi
            config.drives.append(drive)
            drive.imageType = .cd
            config.drives.append(drive)
        }
    }
}
