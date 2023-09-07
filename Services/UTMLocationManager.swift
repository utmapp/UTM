//
// Copyright © 2023 osy. All rights reserved.
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

import Foundation
import CoreLocation

class UTMLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = UTMLocationManager()
    public var locationManager: CLLocationManager
    
    private override init() {
        locationManager = CLLocationManager()
        locationManager.delegate = UTMLocationManager.shared
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        UTMLog("Location manager failed with: %@", error)
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied {
            UTMLog("Location serivces are disabled in settings.")
        } else {
            startUpdatingLocation()
        }
    }
    
    public func startUpdatingLocation() {
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }
}
