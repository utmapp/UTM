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
private enum IconStyle: String, Identifiable, CaseIterable {
    case generic = "Generic"
    case operatingSystem = "Operating System"
    case custom = "Custom"
    
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
    var id: String { rawValue }
}

@available(iOS 14, macOS 11, *)
struct VMConfigInfoView<Config: ObservableObject & UTMConfigurable>: View {
    @ObservedObject var config: Config
    @State private var imageSelectVisible: Bool = false
    @State private var iconStyle: IconStyle = .generic
    @State private var warningMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if os(macOS)
            HStack {
                Text("Name").frame(width: 50, alignment: .trailing)
                nameField
            }
            HStack(alignment: .top) {
                Text("Notes").frame(width: 50, alignment: .trailing)
                notesField
            }
            HStack {
                Text("Icon").frame(width: 50, alignment: .trailing)
                iconSelector
                    .aspectRatio(1, contentMode: .fill)
                iconStylePicker
            }
            #else
            Form {
                Section(header: Text("Name")) {
                    nameField
                }
                Section(header: Text("Notes")) {
                    notesField
                }
                Section(header: Text("Icon")) {
                    iconStylePicker
                    iconSelector
                }
                Section(header: Text("Screenshots")) {
                    
                }
            }
            #endif
        }.onAppear {
            if config.iconCustom {
                iconStyle = .custom
            } else if config.iconUrl != nil {
                iconStyle = .operatingSystem
            }
        }.alert(item: $warningMessage) { warning in
            Alert(title: Text(warning))
        }.disableAutocorrection(true)
    }
    
    
    private var screenshotsField: some View {
        Toggle("Enable Screenshots", isOn: $config.isScreenshotEnabled)
    }
    private var nameField: some View {
        TextField("Name", text: $config.name, onEditingChanged: validateName)
            .keyboardType(.asciiCapable)
            .disabled(config.isRenameDisabled)
    }

    private var notesField: some View {
        TextEditor(text: $config.notes.bound)
            #if os(macOS)
            .border(Color.primary, width: 0.5)
            #endif
            .frame(minHeight: 200)
    }

    @ViewBuilder
    private var iconStylePicker: some View {
        let style = Binding<IconStyle> {
            return iconStyle
        } set: {
            iconStyle = $0
            switch iconStyle {
            case .generic:
                config.icon = ""
                config.selectedCustomIconPath = nil
                break
            case .operatingSystem:
                config.iconCustom = false
                config.selectedCustomIconPath = nil
                break
            case .custom:
                config.iconCustom = true
                break
            }
        }

        Picker(selection: style.animation(), label: Text("Style")) {
            ForEach(IconStyle.allCases, id: \.id) { value in
                Text(value.localizedName)
                    .tag(value)
            }
        }
        #if os(macOS)
        .pickerStyle(.radioGroup)
        .labelsHidden()
        #endif
    }

    @ViewBuilder
    private var iconSelector: some View {
        switch iconStyle {
        case .custom:
            #if os(macOS)
            Button(action: { imageSelectVisible.toggle() }, label: {
                IconPreview(url: config.iconUrl)
            }).fileImporter(isPresented: $imageSelectVisible, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    imageCustomSelected(url: url)
                case .failure:
                    break
                }
            }.buttonStyle(.plain)
            #else
            Button(action: { imageSelectVisible.toggle() }, label: {
                IconPreview(url: config.iconUrl)
            }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                ImagePicker(onImageSelected: imageCustomSelected)
            }.buttonStyle(.plain)
            #endif
        case .operatingSystem:
            Button(action: { imageSelectVisible.toggle() }, label: {
                IconPreview(url: config.iconUrl)
            }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                IconSelect(onIconSelected: imageSelected)
            }.buttonStyle(.plain)
        default:
            #if os(macOS)
            Image(systemName: "desktopcomputer")
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .padding()
                .foregroundColor(Color(NSColor.disabledControlTextColor))
            #else
            EmptyView()
            #endif
        }
    }
    
    private func validateName(editing: Bool) {
        guard !editing else {
            return
        }
        let fileManager = FileManager.default
        let tempPath = fileManager.temporaryDirectory
        let fakeFile = tempPath.appendingPathComponent(config.name)
        if fileManager.createFile(atPath: fakeFile.path, contents: nil, attributes: nil) {
            do {
                try fileManager.removeItem(at: fakeFile)
            } catch {
                warningMessage = NSLocalizedString("Failed to check name.", comment: "VMConfigInfoView")
            }
        } else {
            warningMessage = NSLocalizedString("Name is an invalid filename.", comment: "VMConfigInfoView")
        }
    }
    
    private func imageCustomSelected(url: URL?) {
        if let imageURL = url {
            config.selectedCustomIconPath = imageURL
            config.iconCustom = true
        }
        imageSelectVisible = false
    }
    
    private func imageSelected(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        config.icon = name
        config.iconCustom = false
        imageSelectVisible = false
    }
}

@available(iOS 14, macOS 11, *)
private struct IconPreview: View {
    let url: URL?
    
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    var body: some View {
        HStack {
            #if !os(macOS)
            Spacer()
            #endif
            Logo(logo: PlatformImage(contentsOfURL: url))
                .padding()
            #if !os(macOS)
            Spacer()
            #endif
        }
    }
}

@available(iOS 14, macOS 11, *)
private struct IconSelect: View {
    let onIconSelected: (URL) -> Void
    private let gridLayout = [GridItem(.adaptive(minimum: 60))]
    private var icons: [URL] {
        let paths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: "Icons")
        let urls = paths.map({ URL(fileURLWithPath: $0) })
        return urls.sorted { urlA, urlB in
            urlA.lastPathComponent < urlB.lastPathComponent
        }
    }
    
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    struct IconSelectModifier: ViewModifier {
        @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
        
        #if os(macOS)
        let isPhone: Bool = false
        #else
        var isPhone: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }
        #endif
        
        func body(content: Content) -> some View {
            if isPhone {
                return AnyView(
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { presentationMode.wrappedValue.dismiss() }, label: {
                                Text("Cancel")
                            }).padding()
                        }
                        ScrollView {
                            content.padding(.bottom)
                        }
                    }
                )
            } else {
                return AnyView(
                    ScrollView {
                        content.padding([.top, .bottom])
                    }.frame(width: 400, height: 400)
                )
            }
        }
    }
    
    var body: some View {
        LazyVGrid(columns: gridLayout, spacing: 30) {
            ForEach(icons, id: \.self) { icon in
                Button(action: { onIconSelected(icon) }, label: {
                    Logo(logo: PlatformImage(contentsOfURL: icon))
                }).buttonStyle(.plain)
            }
        }.modifier(IconSelectModifier())
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigInfoView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        Group {
            VMConfigInfoView(config: config)
            IconSelect() { _ in
                
            }
        }
    }
}
