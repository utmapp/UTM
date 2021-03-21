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

import UIKit

class VMUSBDevicesViewController: UIViewController {
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @objc weak var vmUsbManager: CSUSBManager?
    
    private let refreshControl = UIRefreshControl()
    private var allUsbDevices: [CSUSBDevice] = []
    private var connectedUsbDevices: [CSUSBDevice] = []
    
    private let cellIdentifier = "usbDeviceCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshDevices), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshDevices()
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func refreshDevices(_ sender: Any = self) {
        self.refreshControl.beginRefreshing()
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = self.vmUsbManager?.usbDevices ?? []
            DispatchQueue.main.async {
                self.allUsbDevices = devices
                self.tableView?.reloadData()
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    @objc public func addDevice(_ device: CSUSBDevice, onCompletion: @escaping (Bool, String?) -> Void) {
        guard let vmUsbManager = self.vmUsbManager else {
            logger.error("invalid usb manager")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            vmUsbManager.connectUsbDevice(device) { (success, message) in
                if success {
                    DispatchQueue.main.async {
                        self.connectedUsbDevices.append(device)
                        self.refreshDevices()
                    }
                }
                onCompletion(success, message)
            }
        }
    }
    
    @objc public func removeDevice(_ device: CSUSBDevice) {
        guard let vmUsbManager = self.vmUsbManager else {
            logger.error("invalid usb manager")
            return
        }
        DispatchQueue.main.async {
            self.connectedUsbDevices.removeAll(where: { $0 == device })
        }
        DispatchQueue.global(qos: .userInitiated).async {
            vmUsbManager.disconnectUsbDevice(device) { (_, _) in }
        }
    }
    
    @objc public func clearDevices() {
        connectedUsbDevices.removeAll()
        allUsbDevices.removeAll()
    }
}

extension VMUSBDevicesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return allUsbDevices.count
        } else {
            return 0
        }
    }
    
    private func defaultCell() -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) {
            return cell
        } else {
            return UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        }
    }
    
    private func isUsbDeviceValid(_ device: CSUSBDevice) -> Bool {
        let canRedirect = vmUsbManager?.canRedirectUsbDevice(device, errorMessage: nil) ?? false
        let isConnected = vmUsbManager?.isUsbDeviceConnected(device) ?? false
        let isConnectedToSelf = connectedUsbDevices.contains(device)
        return canRedirect && (isConnectedToSelf || !isConnected)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = defaultCell()
        guard indexPath.section == 0 else {
            return cell
        }
        let device = allUsbDevices[indexPath.row]
        let isConnectedToSelf = connectedUsbDevices.contains(device)
        let isEnabled = isUsbDeviceValid(device)
        cell.textLabel!.text = device.name ?? device.description
        cell.accessoryType = isConnectedToSelf ? .checkmark : .none
        cell.isUserInteractionEnabled = isEnabled
        cell.textLabel!.isEnabled = isEnabled
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard indexPath.section == 0 else {
            return nil
        }
        let device = allUsbDevices[indexPath.row]
        guard isUsbDeviceValid(device) else {
            return nil
        }
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }
        guard let vmUsbManager = self.vmUsbManager else {
            logger.error("usb manager not valid")
            return
        }
        let device = allUsbDevices[indexPath.row]
        let isConnectedToSelf = connectedUsbDevices.contains(device)
        let callback = { (success: Bool, message: String?) in
            DispatchQueue.main.async {
                if let msg = message {
                    self.showAlert(msg, actions: nil, completion: nil)
                }
                if success {
                    if isConnectedToSelf {
                        self.connectedUsbDevices.removeAll(where: { $0 == device })
                    } else {
                        self.connectedUsbDevices.append(device)
                    }
                }
                self.refreshDevices()
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if isConnectedToSelf {
                vmUsbManager.disconnectUsbDevice(device, withCompletion: callback)
            } else {
                vmUsbManager.connectUsbDevice(device, withCompletion: callback)
            }
        }
    }
}
