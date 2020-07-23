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

private enum IconStyle: String, Identifiable, CaseIterable {
    case generic = "Generic"
    case operatingSystem = "Operating System"
    case custom = "Custom"
    
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
    var id: String { rawValue }
}

struct VMConfigInfoView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var imageSelectVisible: Bool = false
    @State private var iconStyle: IconStyle = .generic
    
    private var existingCustomImage: URL? {
        if let current = config.selectedCustomIconPath {
            return current // if we just selected a path
        }
        guard let parent = config.existingPath else {
            return nil
        }
        guard let icon = config.icon else {
            return nil
        }
        return parent.appendingPathComponent(icon) // from saved config
    }
    
    private var existingImage: URL? {
        guard let icon = config.icon else {
            return nil
        }
        if let path = Bundle.main.path(forResource: icon, ofType: "png", inDirectory: "Icons") {
            return URL(fileURLWithPath: path)
        } else {
            return nil
        }
    }
    
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
                        Button(action: { imageSelectVisible.toggle() }, label: {
                            IconPreview(url: existingCustomImage)
                        }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                            ImagePicker(onImageSelected: imageCustomSelected)
                        }.buttonStyle(PlainButtonStyle())
                    case .operatingSystem:
                        Button(action: { imageSelectVisible.toggle() }, label: {
                            IconPreview(url: existingImage)
                        }).popover(isPresented: $imageSelectVisible, arrowEdge: .bottom) {
                            IconSelect(onIconSelected: imageSelected)
                        }.buttonStyle(PlainButtonStyle())
                    default:
                        EmptyView()
                    }
                }
            }
        }.onAppear {
            if config.iconCustom {
                iconStyle = .custom
            } else if existingImage != nil {
                iconStyle = .operatingSystem
            }
        }
    }
    
    private func validateName() {
        
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

private struct IconPreview: View {
    let url: URL?
    
    var body: some View {
        HStack {
            Spacer()
            Logo(logo: UIImage(contentsOfURL: url))
                .padding()
            Spacer()
        }
    }
}

private struct IconSelect: View {
    let onIconSelected: (URL) -> Void
    private let gridLayout = [GridItem(.adaptive(minimum: 60))]
    private var icons: [URL] {
        let paths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: "Icons")
        return paths.map({ URL(fileURLWithPath: $0) })
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridLayout, spacing: 30) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: { onIconSelected(icon) }, label: {
                        Logo(logo: UIImage(contentsOfURL: icon))
                    }).buttonStyle(PlainButtonStyle())
                }
            }.padding([.top, .bottom])
        }
    }
}

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
