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
struct VMConfigInfoView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var imageSelectVisible: Bool = false
    @State private var iconStyle: IconStyle = .generic
    @State private var warningMessage: String? = nil
    @Environment(\.importFiles) private var importFiles: ImportFilesAction
    
    var body: some View {
        VStack {
            Form {
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

                Section(header: Text("Name"), footer: EmptyView().padding(.bottom)) {
                    TextField("Name", text: $config.name, onCommit: validateName)
                        .keyboardType(.asciiCapable)
                }
                Section(header: Text("Notes"), footer: EmptyView().padding(.bottom)) {
                    TextEditor(text: $config.notes.bound)
                        .frame(minHeight: 200)
                }
                Section(header: Text("Icon"), footer: EmptyView().padding(.bottom)) {
                    Picker(selection: style.animation(), label: Text("Style")) {
                        ForEach(IconStyle.allCases, id: \.id) { value in
                            Text(value.localizedName)
                                .tag(value)
                        }
                    }
                    
                    switch iconStyle {
                    case .custom:
                        #if os(macOS)
                        Button(action: imageCustomSelect, label: {
                            IconPreview(url: config.existingCustomIconURL)
                        }).buttonStyle(PlainButtonStyle())
                        #else
                        Button(action: { imageSelectVisible.toggle() }, label: {
                            IconPreview(url: config.existingCustomIconURL)
                        }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                            ImagePicker(onImageSelected: imageCustomSelected)
                        }.buttonStyle(PlainButtonStyle())
                        #endif
                    case .operatingSystem:
                        Button(action: { imageSelectVisible.toggle() }, label: {
                            IconPreview(url: config.existingIconURL)
                        }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                            IconSelect(onIconSelected: imageSelected)
                                .frame(width: 400, height: 400)
                        }.buttonStyle(PlainButtonStyle())
                    default:
                        EmptyView()
                    }
                }
            }
        }.onAppear {
            if config.iconCustom {
                iconStyle = .custom
            } else if config.existingIconURL != nil {
                iconStyle = .operatingSystem
            }
        }.alert(item: $warningMessage) { warning in
            Alert(title: Text(warning))
        }
    }
    
    private func validateName() {
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
    
    #if os(macOS)
    private func imageCustomSelect() {
        importFiles(singleOfType: [.image]) { result in
            switch result {
            case .success(let url):
                imageCustomSelected(url: url)
            case .failure:
                break
            case .none:
                break
            }
        }
    }
    #endif
    
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
            Spacer()
            Logo(logo: PlatformImage(contentsOfURL: url))
                .padding()
            Spacer()
        }
    }
}

@available(iOS 14, macOS 11, *)
private struct IconSelect: View {
    let onIconSelected: (URL) -> Void
    private let gridLayout = [GridItem(.adaptive(minimum: 60))]
    private var icons: [URL] {
        let paths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: "Icons")
        return paths.map({ URL(fileURLWithPath: $0) })
    }
    
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridLayout, spacing: 30) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: { onIconSelected(icon) }, label: {
                        Logo(logo: PlatformImage(contentsOfURL: icon))
                    }).buttonStyle(PlainButtonStyle())
                }
            }.padding([.top, .bottom])
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigInfoView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMConfigInfoView(config: config)
            IconSelect() { _ in
                
            }
        }
    }
}
