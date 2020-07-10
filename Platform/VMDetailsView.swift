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
    var vm: UTMVirtualMachine
    @State private var settingsSheetPresented: Bool = false
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    private var regularScreenSizeClass: Bool {
        horizontalSizeClass == .regular
    }
    
    private var toolbarPlacement: ToolbarItemPlacement {
        regularScreenSizeClass ? .navigationBarTrailing : .bottomBar
    }
    #else
    private let regularScreenSizeClass: Bool = true
    private let toolbarPlacement: ToolbarItemPlacement = .automatic
    #endif
    
    var body: some View {
        ScrollView {
            Screenshot(vm: vm)
            if regularScreenSizeClass {
                HStack(alignment: .top) {
                    Details(config: vm.configuration)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.") // FIXME: implement this
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VMRemovableDrivesView(config: vm.configuration)
                    .padding([.leading, .trailing, .bottom])
            } else {
                VStack {
                    Details(config: vm.configuration)
                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
                        .font(.body)
                    VMRemovableDrivesView(config: vm.configuration)
                }.padding([.leading, .trailing, .bottom])
            }
        }.labelStyle(DetailsLabelStyle())
        .navigationTitle(vm.configuration.name)
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                VMToolbar {
                    settingsSheetPresented.toggle()
                }
            }
        }.sheet(isPresented: $settingsSheetPresented) {
            #if !os(macOS) // sheet only for iOS
            NavigationView {
                VMSettingsView(config: vm.configuration) { _ in
                    data.busyWork() { try data.save(vm: vm) }
                }
            }
            #endif
        }
    }
}

struct Screenshot: View {
    var vm: UTMVirtualMachine
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            if vm.screenshot.image != nil {
                #if os(macOS)
                Image(nsImage: vm.screenshot.image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: vm.screenshot.image!)
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
        }.aspectRatio(CGSize(width: 16, height: 9), contentMode: .fill)
    }
}

struct Details: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            HStack {
                Label("Architecture", systemImage: "cpu")
                Spacer()
                Text(config.systemArchitecturePretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("Machine", systemImage: "desktopcomputer")
                Spacer()
                Text(config.systemTargetPretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("Memory", systemImage: "memorychip")
                Spacer()
                Text(config.systemMemoryPretty)
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("Size", systemImage: "internaldrive")
                Spacer()
                Text("12 GB") // TODO: get actual size
                    .foregroundColor(.secondary)
            }
        }.lineLimit(1)
        .truncationMode(.tail)
    }
}

struct DetailsLabelStyle: LabelStyle {
    var color: Color = .accentColor
    
    func makeBody(configuration: Configuration) -> some View {
        Label(
            title: { configuration.title.font(.headline) },
            icon: {
                Rectangle() // FIXME: SwiftUI bug misaligns icon
                    .frame(width: 32, height: 32)
                    .foregroundColor(.clear)
                    .overlay(configuration.icon.foregroundColor(color))
            })
    }
}

struct VMDetailsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMDetailsView(vm: UTMVirtualMachine(configuration: config, withDestinationURL: URL(fileURLWithPath: "")))
        .onAppear {
            config.shareDirectoryEnabled = true
            config.newDrive("", type: .disk, interface: "ide")
            config.newDrive("", type: .disk, interface: "sata")
            config.newDrive("", type: .CD, interface: "ide")
        }
    }
}
