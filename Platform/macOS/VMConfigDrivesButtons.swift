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

struct VMConfigDrivesButtons: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMConfiguration
    @Binding var selectedDriveIndex: Int?
    
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        Group {
            Button {
                
            } label: {
                Label("New Drive", systemImage: "externaldrive.badge.plus")
            }.help("Add a new drive.")
            if let index = selectedDriveIndex, index != 0 {
                Button {
                    deleteDrive(atIndex: index)
                } label: {
                    Label("Delete Drive", systemImage: "externaldrive.badge.plus")
                }.help("Delete this drive.")
                Button {
                    moveDriveUp(fromIndex: index)
                } label: {
                    Label("Move Up", systemImage: "chevron.up")
                }.help("Make boot order priority higher.")
                if index != config.countDrives - 1 {
                    Button {
                        moveDriveDown(fromIndex: index)
                    } label: {
                        Label("Move Down", systemImage: "chevron.down")
                    }.help("Make boot order priority lower.")
                }
            }
        }.labelStyle(TitleOnlyLabelStyle())
    }
    
    func deleteDrive(atIndex index: Int) {
        data.busyWork {
            try data.removeDrive(at: index, for: config)
        }
    }
    
    func moveDriveUp(fromIndex index: Int) {
        withAnimation {
            config.moveDrive(index, to: index - 1)
            selectedDriveIndex = index - 1
        }
    }
    
    func moveDriveDown(fromIndex index: Int) {
        withAnimation {
            config.moveDrive(index, to: index + 1)
            selectedDriveIndex = index + 1
        }
    }
}
