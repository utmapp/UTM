//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

/// Accessibility identifiers of the controls the UI tests drive.
///
/// The identifiers are stable names: `utm.<screen>.<element>`, with a page segment where a
/// screen has pages (`utm.wizard.start.emulate`). They never change with the localized
/// labels, so tests find a control the same way in every language. Controls that exist once
/// per VM append the VM's name.
enum UTMAccessibilityID {
    enum Library {
        static let newVM = "utm.library.newVM"
        
        /// The row of the VM with this name.
        static func card(named name: String) -> String {
            "utm.library.card." + name
        }
        
        /// The Run button in the row of the VM with this name.
        static func run(named name: String) -> String {
            "utm.library.run." + name
        }
    }
    
    enum Details {
        static let run = "utm.details.run"
        static let stop = "utm.details.stop"
        static let edit = "utm.details.edit"
        static let delete = "utm.details.delete"
        static let clone = "utm.details.clone"
        static let move = "utm.details.move"
        static let share = "utm.details.share"
    }
    
    enum Wizard {
        static let virtualize = "utm.wizard.start.virtualize"
        static let emulate = "utm.wizard.start.emulate"
        static let open = "utm.wizard.start.open"
        static let osMacOS = "utm.wizard.os.macOS"
        static let osClassicMacOS = "utm.wizard.os.classicMacOS"
        static let osWindows = "utm.wizard.os.windows"
        static let osLinux = "utm.wizard.os.linux"
        static let osOther = "utm.wizard.os.other"
        static let cancel = "utm.wizard.cancel"
        static let back = "utm.wizard.back"
        static let `continue` = "utm.wizard.continue"
        static let save = "utm.wizard.save"
        static let expertMode = "utm.wizard.hardware.expertMode"
        static let architecture = "utm.wizard.hardware.architecture"
        static let target = "utm.wizard.hardware.target"
        static let machine = "utm.wizard.hardware.machine"
        static let cores = "utm.wizard.hardware.cores"
        static let storageSize = "utm.wizard.drives.size"
        static let name = "utm.wizard.summary.name"
    }
    
    enum Settings {
        static let save = "utm.settings.save"
        static let cancel = "utm.settings.cancel"
        static let information = "utm.settings.sidebar.information"
        static let system = "utm.settings.sidebar.system"
        static let qemu = "utm.settings.sidebar.qemu"
        static let input = "utm.settings.sidebar.input"
        static let sharing = "utm.settings.sidebar.sharing"
        static let addDevice = "utm.settings.addDevice"
        static let architecture = "utm.settings.system.architecture"
        static let target = "utm.settings.system.target"
        static let newDrive = "utm.settings.drives.new"
        static let importDrive = "utm.settings.drives.import"
        static let shareMode = "utm.settings.sharing.mode"
    }
    
    /// The sheet or popover that creates a drive.
    enum Drive {
        static let removable = "utm.drive.removable"
        static let interface = "utm.drive.interface"
        static let size = "utm.drive.size"
        static let sizeUnit = "utm.drive.sizeUnit"
        static let create = "utm.drive.create"
        static let cancel = "utm.drive.cancel"
        static let `import` = "utm.drive.import"
    }
    
    static let busyIndicator = "utm.busy.indicator"
}
