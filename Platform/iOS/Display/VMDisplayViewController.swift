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

private var memoryAlertOnce = false

@objc public extension VMDisplayViewController {
    var runInBackground: Bool {
        boolForSetting("RunInBackground")
    }
    
    var disableIdleTimer: Bool {
        boolForSetting("DisableIdleTimer")
    }
}

// MARK: - View Loading
public extension VMDisplayViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let parent = parent {
            parent.setChildForHomeIndicatorAutoHidden(nil)
            parent.setChildViewControllerForPointerLock(nil)
            UIPress.pressResponderOverride = nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let parent = parent {
            parent.setChildForHomeIndicatorAutoHidden(self)
            parent.setChildViewControllerForPointerLock(self)
            UIPress.pressResponderOverride = self
        }
        #if !os(visionOS) && WITH_LOCATION_BACKGROUND
        if runInBackground {
            logger.info("Start location tracking to enable running in background")
            UTMLocationManager.sharedInstance().startUpdatingLocation()
        }
        #endif
        delegate.displayDidAppear()
    }
}

@objc extension VMDisplayViewController {
    func enterSuspended(isBusy busy: Bool) {
        if !busy {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    func enterLive() {
        UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
    }
}

// MARK: Toolbar hiding
public extension VMDisplayViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch.type == .direct {
                delegate.displayDidAssertUserInteraction()
                break
            }
        }
        super.touchesBegan(touches, with: event)
    }
}

// MARK: Helper functions
@objc public extension VMDisplayViewController {
    /*
     - (void)onDelay:(float)delay action:(void (^)(void))block {
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*0.1), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), block);
     }

     - (BOOL)boolForSetting:(NSString *)key {
         return [[NSUserDefaults standardUserDefaults] boolForKey:key];
     }

     - (NSInteger)integerForSetting:(NSString *)key {
         return [[NSUserDefaults standardUserDefaults] integerForKey:key];
     }
     */
    func onDelay(_ delay: Float, action: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(100), execute: action)
    }
    
    func boolForSetting(_ key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func integerForSetting(_ key: String) -> Int {
        return UserDefaults.standard.integer(forKey: key)
    }

    @discardableResult
    func debounce(_ delaySeconds: Int, context: Any? = nil, action: @escaping () -> Void) -> Any {
        if context != nil {
            let previous = context as! DispatchWorkItem
            previous.cancel()
        }
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delaySeconds), execute: item)
        return item
    }
}
