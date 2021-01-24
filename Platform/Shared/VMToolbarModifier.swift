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

// Lots of dirty hacks to work around SwiftUI bugs introduced in Beta 2
@available(iOS 14, macOS 11, *)
struct VMToolbarModifier: ViewModifier {
    let vm: UTMVirtualMachine
    let bottom: Bool
    @ObservedObject private var sessionConfig: UTMViewState
    @State private var showSharePopup = false
    @State private var confirmAction: ConfirmAction?
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    #if os(macOS)
    let destructiveButtonColor: Color = .primary
    let buttonPlacement: ToolbarItemPlacement = .automatic
    let padding: CGFloat = 0
    #else
    let destructiveButtonColor: Color = .red
    var buttonPlacement: ToolbarItemPlacement {
        if bottom {
            return .bottomBar
        } else {
            return .navigationBarTrailing
        }
    }
    var padding: CGFloat {
        if bottom {
            return 0
        } else {
            return 10
        }
    }
    #endif
    
    init(vm: UTMVirtualMachine, bottom: Bool) {
        self.vm = vm
        self.bottom = bottom
        self.sessionConfig = vm.viewState
    }
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: buttonPlacement) {
                Button {
                    confirmAction = .confirmDeleteVM
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(destructiveButtonColor)
                        .labelStyle(IconOnlyLabelStyle())
                }.help("Delete selected VM")
                .padding(.leading, padding)
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                Button {
                    confirmAction = .confirmCloneVM
                } label: {
                    Label("Clone", systemImage: "doc.on.doc")
                        .labelStyle(IconOnlyLabelStyle())
                }.help("Clone selected VM")
                .padding(.leading, padding)
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                Button {
                    showSharePopup.toggle()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(IconOnlyLabelStyle())
                }.help("Share selected VM")
                .padding(.leading, padding)
                .modifier(VMShareItemModifier(isPresented: $showSharePopup) {
                    [vm.path!]
                })
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                if sessionConfig.suspended || sessionConfig.active {
                    Button {
                        confirmAction = .confirmStopVM
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(IconOnlyLabelStyle())
                    }.help("Stop selected VM")
                    .padding(.leading, padding)
                } else {
                    Button {
                        data.run(vm: data.selectedVM!)
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .labelStyle(IconOnlyLabelStyle())
                    }.help("Run selected VM")
                    .padding(.leading, padding)
                }
                #if !os(macOS)
                if bottom {
                    Spacer()
                }
                #endif
                Button {
                    data.edit(vm: vm)
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .labelStyle(IconOnlyLabelStyle())
                }.help("Edit selected VM")
                .disabled(sessionConfig.suspended || sessionConfig.active)
                .padding(.leading, padding)
            }
        }
        .modifier(VMConfirmActionModifier(vm: vm, confirmAction: $confirmAction) {
            presentationMode.wrappedValue.dismiss()
        })
    }
}
