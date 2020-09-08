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

@objc class VMRemovableDrivesViewController: UIViewController {
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @objc weak var vm: UTMVirtualMachine?
    fileprivate var drives: [UTMDrive]?
    fileprivate var selectedDrive: UTMDrive?
    
    let cellIdentifier = "removableDriveCell"
    
    override func viewDidLoad() {
        let cellNib = TableCellNib(nibName: "VMRemovableDrivesView", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshStatus()
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Table delegate
extension VMRemovableDrivesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let drives = self.drives else {
            return 0
        }
        return drives.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! VMRemovableDrivesCell
        guard let drive = self.drives?[indexPath.row] else {
            return cell
        }
        if #available(iOS 14.0, *) {
            switch drive.status {
            case .fixed: cell.icon.image = UIImage(systemName: "internaldrive")
            case .ejected: cell.icon.image = UIImage(systemName: "opticaldiscdrive")
            case .inserted: cell.icon.image = UIImage(systemName: "opticaldiscdrive.fill")
            @unknown default:
                break
            }
        }
        if drive.status != .fixed {
            cell.accessoryType = .disclosureIndicator
        } else if #available(iOS 13.0, *) {
            cell.label.textColor = .secondaryLabel
        }
        cell.label.text = drive.label
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let drive = self.drives?[indexPath.row] else {
            return nil
        }
        guard drive.status != .fixed else {
            return nil
        }
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let drive = self.drives?[indexPath.row] else {
            return
        }
        showOptions(forDrive: drive, sender: tableView.cellForRow(at: indexPath)!)
    }
}

// MARK: - File picker delegate
extension VMRemovableDrivesViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedDrive = self.selectedDrive else {
            logger.error("no drive selected!")
            return
        }
        DispatchQueue.global(qos: .background).async {
            self.changeMedium(forDrive: selectedDrive, url: urls.first)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        selectedDrive = nil
    }
}

// MARK: - Handle removable drives
extension VMRemovableDrivesViewController {
    var fileManager: FileManager {
        FileManager.default
    }
    
    func refreshStatus() {
        if let vm = self.vm {
            drives = vm.drives
        } else {
            drives = nil
        }
        tableView.reloadData()
    }
    
    func eject(drive: UTMDrive, force: Bool) {
        do {
            guard let vm = self.vm else {
                throw NSLocalizedString("Failed to get VM object.", comment: "VMRemovableDrivesViewController")
            }
            try vm.ejectDrive(drive, force: false)
            DispatchQueue.main.async {
                self.refreshStatus()
            }
        } catch {
            showAlert(error.localizedDescription, actions: nil, completion: nil)
        }
    }
    
    func changeMedium(forDrive drive: UTMDrive, url: URL?) {
        do {
            guard let vm = self.vm else {
                throw NSLocalizedString("Failed to get VM object.", comment: "VMRemovableDrivesViewController")
            }
            guard let urlValue = url else {
                throw NSLocalizedString("Invalid file selected.", comment: "VMRemovableDrivesViewController")
            }
            try vm.changeMedium(for: drive, url: urlValue)
            DispatchQueue.main.async {
                self.refreshStatus()
            }
        } catch {
            showAlert(error.localizedDescription, actions: nil, completion: nil)
        }
    }
    
    func changeMediumPrompt(drive: UTMDrive) {
        let filePicker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .open)
        filePicker.delegate = self;
        filePicker.modalPresentationStyle = .formSheet;
        selectedDrive = drive
        present(filePicker, animated: true)
    }
    
    func showOptions(forDrive drive: UTMDrive, sender: UITableViewCell) {
        let alert = UIAlertController(title: NSLocalizedString("Drive Options", comment: "VMRemovableDrivesViewController"),
                                      message: drive.label,
                                      preferredStyle: .actionSheet)
        if drive.status == .inserted {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Eject", comment: "VMRemovableDrivesViewController"),
                                          style: .default,
                                          handler: { _ in
                                            DispatchQueue.global(qos: .background).async {
                                                self.eject(drive: drive, force: false)
                                            }
                                          }))
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Change", comment: "VMRemovableDrivesViewController"),
                                      style: .default,
                                      handler: { _ in
                                        self.changeMediumPrompt(drive: drive)
                                      }))
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: "VMRemovableDrivesViewController"), style: .cancel)
        alert.addAction(cancel)
        alert.preferredAction = cancel
        alert.popoverPresentationController?.sourceView = sender;
        alert.popoverPresentationController?.sourceRect = sender.bounds;
        present(alert, animated: true)
    }
}

// MARK: - Table cell view
class VMRemovableDrivesCell: UITableViewCell {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var label: UILabel!
}

private class TableCellNib: UINib {
    static private let dummy = VMRemovableDrivesViewController()
    let base: UINib
    
    init(nibName name: String, bundle bundleOrNil: Bundle?) {
        self.base = UINib.init(nibName: name, bundle: bundleOrNil)
    }
    
    // We put both the cell and the table in the same NIB for easier management
    // However this means we need some sort of hack to bypass the NIB loading
    override func instantiate(withOwner ownerOrNil: Any?, options optionsOrNil: [UINib.OptionsKey : Any]? = nil) -> [Any] {
        let result = base.instantiate(withOwner: TableCellNib.dummy, options: optionsOrNil)
        return result.compactMap { (existing) -> UITableViewCell? in
            return existing as? UITableViewCell
        }
    }
}
