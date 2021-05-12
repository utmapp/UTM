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

@available(iOS 14, macOS 11, *)
struct VMDetailsView: View {
    let vm: UTMVirtualMachine
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
    
    private var sizeLabel: String {
        let size = data.computeSize(forVM: vm)
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var body: some View {
        if vm.viewState.deleted {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("This virtual machine has been deleted.")
                        .font(.headline)
                    Spacer()
                }
                Spacer()
            }
        } else {
            ScrollView {
                Screenshot(vm: vm, large: regularScreenSizeClass)
                let notes = vm.configuration.notes ?? ""
                if regularScreenSizeClass && !notes.isEmpty {
                    HStack(alignment: .top) {
                        Details(config: vm.configuration, sessionConfig: vm.viewState, sizeLabel: sizeLabel)
                            .padding()
                            .frame(maxWidth: .infinity)
                        Text(notes)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    VMRemovableDrivesView(vm: vm)
                        .padding([.leading, .trailing, .bottom])
                } else {
                    VStack {
                        Details(config: vm.configuration, sessionConfig: vm.viewState, sizeLabel: sizeLabel)
                        if !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VMRemovableDrivesView(vm: vm)
                    }.padding([.leading, .trailing, .bottom])
                }
            }.labelStyle(DetailsLabelStyle())
            .navigationTitle(vm.configuration.name)
            .modifier(VMToolbarModifier(vm: vm, bottom: !regularScreenSizeClass))
            .sheet(isPresented: $data.showSettingsModal) {
                VMSettingsView(vm: vm, config: vm.configuration)
                    .environmentObject(data)
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct Screenshot: View {
    let vm: UTMVirtualMachine
    let large: Bool
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            if vm.screenshot?.image != nil {
                #if os(macOS)
                Image(nsImage: vm.screenshot!.image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: vm.screenshot!.image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            }
            Rectangle()
                .fill(Color(red: 230/255, green: 229/255, blue: 235/255))
                .blendMode(.hardLight)
            Button(action: { data.run(vm: vm) }, label: {
                Label("Run", systemImage: "play.circle.fill")
                    .labelStyle(IconOnlyLabelStyle())
                    .font(Font.system(size: 96))
                    .foregroundColor(Color.black)
            }).buttonStyle(PlainButtonStyle())
        }.aspectRatio(CGSize(width: 16, height: 9), contentMode: large ? .fill : .fit)
    }
}

@available(iOS 14, macOS 11, *)
struct Details: View {
    @ObservedObject var config: UTMConfiguration
    @ObservedObject var sessionConfig: UTMViewState
    let sizeLabel: String
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        VStack {
            HStack {
                plainLabel("Status", systemImage: "info.circle")
                Spacer()
                Text(sessionConfig.active ? "Running" : (sessionConfig.suspended ? "Suspended" : "Not running"))
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Architecture", systemImage: "cpu")
                Spacer()
                Text(config.systemArchitecturePretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Machine", systemImage: "desktopcomputer")
                Spacer()
                Text(config.systemTargetPretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Memory", systemImage: "memorychip")
                Spacer()
                Text(config.systemMemoryPretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                plainLabel("Size", systemImage: "internaldrive")
                Spacer()
                Text(sizeLabel)
                    .foregroundColor(.secondary)
            }
        }.lineLimit(1)
        .truncationMode(.tail)
    }
    
    private func plainLabel(_ text: String, systemImage: String) -> some View {
        return Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage).foregroundColor(.primary)
        }
    }
}

@available(iOS 14, macOS 11, *)
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

@available(iOS 14, macOS 11, *)
struct VMDetailsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMDetailsView(vm: UTMVirtualMachine(configuration: config, withDestinationURL: URL(fileURLWithPath: "")))
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", path: "", type: .disk, interface: "ide")
            config.newDrive("", path: "", type: .disk, interface: "sata")
            config.newDrive("", path: "", type: .CD, interface: "ide")
        }
    }
}
