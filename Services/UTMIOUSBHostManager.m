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

#import "UTMIOUSBHostManager.h"
#import "UTMIOUSBHostDevice.h"
#import "UTMIOUSBHostManagerDelegate.h"
#import <IOKit/usb/IOUSBLib.h>
#import <IOUSBHost/IOUSBHost.h>

extern NSString *const kUTMErrorDomain;
static const int kCooldownClearLastSeenDisconnectSecs = 1;

API_AVAILABLE(macos(15.0))
@interface UTMIOUSBHostManager ()

/// Devices connected to this instance
@property (nonatomic, readonly) NSMutableDictionary<UTMIOUSBHostDevice *, id<VZUSBDevice>> *connectedDevicesMap;

@property (nonatomic, readonly) NSMutableDictionary<NSUUID *, UTMIOUSBHostDevice *> *pendingDevicesMap;

/// Queue to dispatch VM operations
@property (nonatomic, readonly) dispatch_queue_t vmQueue;

@end

API_AVAILABLE(macos(15.0))
@interface UTMIOUSBHostDevice (Private)

@property (nonatomic, nullable, readwrite) NSUUID *uuid;

@end

API_AVAILABLE(macos(15.0))
static NSMutableArray<UTMIOUSBHostDevice *> *gUsbDevices;
static NSPointerArray *gManagers;
static dispatch_queue_t gUsbHostManagerQueue;
static IONotificationPortRef gNotifyPort;
static io_iterator_t gAddedIter;
static io_iterator_t gRemovedIter;
static NSData *gLastRemovedSignature;

static Class ClassVZIOUSBHostPassthroughDeviceConfiguration;
static Class ClassVZIOUSBHostPassthroughDevice;
static BOOL gPassthroughSupported = NO;

static BOOL InitPassthrough(void) API_AVAILABLE(macos(15.0)) {
    ClassVZIOUSBHostPassthroughDeviceConfiguration = NSClassFromString(@"_VZIOUSBHostPassthroughDeviceConfiguration");
    ClassVZIOUSBHostPassthroughDevice = NSClassFromString(@"_VZIOUSBHostPassthroughDevice");
    if (!ClassVZIOUSBHostPassthroughDeviceConfiguration || !ClassVZIOUSBHostPassthroughDevice) {
        return NO;
    }
    if (![ClassVZIOUSBHostPassthroughDeviceConfiguration instancesRespondToSelector:NSSelectorFromString(@"initWithService:error:")]) {
        return NO;
    }
    if (![ClassVZIOUSBHostPassthroughDevice instancesRespondToSelector:NSSelectorFromString(@"initWithConfiguration:error:")]) {
        return NO;
    }
    if (![VZUSBController instancesRespondToSelector:NSSelectorFromString(@"setDelegate:")]) {
        return NO;
    }
    return YES;
}

static void DeviceAdded(void *refCon, io_iterator_t iterator) API_AVAILABLE(macos(15.0)) {
    io_service_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        UTMIOUSBHostDevice *device = [[UTMIOUSBHostDevice alloc] initWithService:usbDevice];
        [gUsbDevices addObject:device];
        // if this was the device we just removed, it can be from capture release
        if (gLastRemovedSignature && [device.usbSignature isEqualToData:gLastRemovedSignature]) {
            gLastRemovedSignature = nil;
            continue; // do not alert delegates
        }
        for (UTMIOUSBHostManager *manager in gManagers) {
            if ([manager.delegate respondsToSelector:@selector(ioUsbHostManager:deviceAttached:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [manager.delegate ioUsbHostManager:manager deviceAttached:device];
                });
            }
        }
    }
}

static void DeviceRemoved(void *refCon, io_iterator_t iterator) API_AVAILABLE(macos(15.0)) {
    io_service_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        UTMIOUSBHostDevice *removedDevice = nil;
        for (UTMIOUSBHostDevice *device in gUsbDevices) {
            if (device.ioService == usbDevice || IOObjectIsEqualTo(device.ioService, usbDevice)) {
                removedDevice = device;
                break;
            }
        }
        if (removedDevice) {
            [gUsbDevices removeObject:removedDevice];
            gLastRemovedSignature = removedDevice.usbSignature;
            // cooldown to clear last removed
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*kCooldownClearLastSeenDisconnectSecs), gUsbHostManagerQueue, ^{
                gLastRemovedSignature = nil;
            });
        }
        IOObjectRelease(usbDevice);
    }
}

static void InitUsbNotify(void) API_AVAILABLE(macos(15.0)) {
    if (gNotifyPort != NULL) {
        return;
    }
    gUsbDevices = [[NSMutableArray alloc] init];
    gManagers = [NSPointerArray weakObjectsPointerArray];
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    gNotifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    IONotificationPortSetDispatchQueue(gNotifyPort, gUsbHostManagerQueue);
    
    CFRetain(matchingDict); // Need another reference for the second call
    
    IOServiceAddMatchingNotification(gNotifyPort, kIOFirstMatchNotification, matchingDict, DeviceAdded, NULL, &gAddedIter);
    DeviceAdded(NULL, gAddedIter); // Iterate already existing devices
    
    IOServiceAddMatchingNotification(gNotifyPort, kIOTerminatedNotification, matchingDict, DeviceRemoved, NULL, &gRemovedIter);
    DeviceRemoved(NULL, gRemovedIter); // Clear any already removed devices (unlikely)
}

static void CleanupUsbNotify(void) API_AVAILABLE(macos(15.0)) {
    if (gAddedIter) {
        IOObjectRelease(gAddedIter);
        gAddedIter = 0;
    }
    if (gRemovedIter) {
        IOObjectRelease(gRemovedIter);
        gRemovedIter = 0;
    }
    if (gNotifyPort != NULL) {
        IONotificationPortDestroy(gNotifyPort);
        gNotifyPort = NULL;
    }
    gUsbDevices = nil;
    gManagers = nil;
}

@implementation UTMIOUSBHostManager

- (instancetype)initWithVirtualMachineQueue:(dispatch_queue_t)virtualMachineQueue {
    if (@available(macOS 15, *)) {
        self = [super init];
        if (self) {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                gPassthroughSupported = InitPassthrough();
                gUsbHostManagerQueue = dispatch_queue_create("com.utmapp.UTM.USBHostManagerQueue", DISPATCH_QUEUE_SERIAL);
            });
            
            if (!gPassthroughSupported) {
                return nil;
            }
            
            _connectedDevicesMap = [[NSMutableDictionary alloc] init];
            _pendingDevicesMap = [[NSMutableDictionary alloc] init];
            _vmQueue = virtualMachineQueue;
            
            dispatch_async(gUsbHostManagerQueue, ^{
                InitUsbNotify();
                [gManagers addPointer:(__bridge void *)self];
                [gManagers compact];
            });
        }
    } else {
        self = nil;
    }
    return self;
}

- (void)dealloc {
    dispatch_async(gUsbHostManagerQueue, ^{
        for (NSUInteger i = 0; i < gManagers.count; i++) {
            if ([gManagers pointerAtIndex:i] == (__bridge void *)self) {
                [gManagers removePointerAtIndex:i];
                break;
            }
        }
        [gManagers compact];
        
        if (@available(macOS 15, *)) {
            if (gManagers.count == 0) {
                CleanupUsbNotify();
            }
        }
    });
}

- (NSError *)errorWithMessage:(nullable NSString *)message {
    return [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (nullable id<VZUSBDeviceConfiguration>)createVzUsbDeviceConfigFromUsbDevice:(UTMIOUSBHostDevice *)usbDevice uuid:(nullable NSUUID *)uuid error:(NSError **)error API_AVAILABLE(macos(15.0)){
    io_service_t ioService = usbDevice.ioService;

    assert(ioService);
    SEL initSel = NSSelectorFromString(@"initWithService:error:");
    id<VZUSBDeviceConfiguration> (*initWithServiceError)(id, SEL, io_service_t, NSError **) = (void *)[ClassVZIOUSBHostPassthroughDeviceConfiguration instanceMethodForSelector:initSel];
    id<VZUSBDeviceConfiguration> config = [ClassVZIOUSBHostPassthroughDeviceConfiguration alloc];
    config = initWithServiceError(config, initSel, ioService, error);
    
    if (!config) {
        return nil;
    }
    if (uuid) {
        config.uuid = uuid;
    }
    
    return config;
}

- (nullable id<VZUSBDevice>)createVzUsbDeviceFromUsbDevice:(UTMIOUSBHostDevice *)usbDevice uuid:(nullable NSUUID *)uuid error:(NSError **)error API_AVAILABLE(macos(15.0)){
    id<VZUSBDeviceConfiguration> config = [self createVzUsbDeviceConfigFromUsbDevice:usbDevice uuid:uuid error:error];
    
    if (!config) {
        return nil;
    }
    
    SEL initSel = NSSelectorFromString(@"initWithConfiguration:error:");
    id<VZUSBDevice> (*initWithConfigurationError)(id, SEL, id, NSError **) = (void *)[ClassVZIOUSBHostPassthroughDevice instanceMethodForSelector:initSel];
    id<VZUSBDevice> device = [ClassVZIOUSBHostPassthroughDevice alloc];
    device = initWithConfigurationError(device, initSel, config, error);
    
    return device;
}

- (void)usbController:(VZUSBController *)usbController setDelegate:(id)delegate API_AVAILABLE(macos(15.0)) {
    SEL setDelegateSel = NSSelectorFromString(@"setDelegate:");
    void (*setDelegate)(id, SEL, id) = (void *)[VZUSBController instanceMethodForSelector:setDelegateSel];
    setDelegate(usbController, setDelegateSel, delegate);
}

- (void)usbController:(VZUSBController *)usbController passthroughDeviceDidDisconnect:(id<VZUSBDevice>)device API_AVAILABLE(macos(15.0)) {
    dispatch_async(gUsbHostManagerQueue, ^{
        UTMIOUSBHostDevice *disconnectedDevice = nil;
        for (UTMIOUSBHostDevice *usbDevice in self.connectedDevicesMap) {
            if (self.connectedDevicesMap[usbDevice] == device) {
                disconnectedDevice = usbDevice;
                break;
            }
        }
        if (disconnectedDevice) {
            disconnectedDevice.uuid = nil;
            [self.connectedDevicesMap removeObjectForKey:disconnectedDevice];
            if ([self.delegate respondsToSelector:@selector(ioUsbHostManager:deviceRemoved:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate ioUsbHostManager:self deviceRemoved:disconnectedDevice];
                });
            }
        }
    });
}

- (void)usbDevicesWithCompletion:(void (^)(NSArray<UTMIOUSBHostDevice *> *devices, NSError * _Nullable error))completion {
    dispatch_async(gUsbHostManagerQueue, ^{
        NSArray *devicesCopy = [gUsbDevices copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(devicesCopy, nil);
        });
    });
}

- (void)connectUsbDevice:(UTMIOUSBHostDevice *)usbDevice toVirtualMachine:(VZVirtualMachine *)virtualMachine withCompletion:(void (^)(NSError * _Nullable error))completion {
    VZUSBController *firstController = virtualMachine.usbControllers.firstObject;
    if (!firstController) {
        completion([self errorWithMessage:NSLocalizedString(@"This virtual machine does not have any USB controllers.", "UTMIOUSBHostManager")]);
        return;
    }
    [self usbController:firstController setDelegate:self];
    dispatch_async(gUsbHostManagerQueue, ^{
        if (usbDevice.uuid != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self errorWithMessage:NSLocalizedString(@"This USB device is already connected to a virtual machine.", "UTMIOUSBHostManager")]);
            });
            return;
        }
        NSError *error = nil;
        id<VZUSBDevice> vzDevice = [self createVzUsbDeviceFromUsbDevice:usbDevice uuid:nil error:&error];
        if (!vzDevice) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
            return;
        }
        usbDevice.uuid = vzDevice.uuid;
        dispatch_async(self.vmQueue, ^{
            [firstController attachDevice:vzDevice completionHandler:^(NSError * _Nullable attachError) {
                dispatch_async(gUsbHostManagerQueue, ^{
                    if (!attachError) {
                        self.connectedDevicesMap[usbDevice] = vzDevice;
                    } else {
                        usbDevice.uuid = nil;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(attachError);
                    });
                });
            }];
        });
    });
}

- (void)disconnectUsbDevice:(UTMIOUSBHostDevice *)usbDevice toVirtualMachine:(VZVirtualMachine *)virtualMachine withCompletion:(void (^)(NSError * _Nullable error))completion {
    VZUSBController *firstController = virtualMachine.usbControllers.firstObject;
    if (!firstController) {
        completion([self errorWithMessage:NSLocalizedString(@"This virtual machine does not have any USB controllers.", "UTMIOUSBHostManager")]);
        return;
    }
    dispatch_async(gUsbHostManagerQueue, ^{
        if (usbDevice.uuid == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self errorWithMessage:NSLocalizedString(@"This USB device is not connected to a virtual machine.", "UTMIOUSBHostManager")]);
            });
            return;
        }
        id<VZUSBDevice> vzDevice = self.connectedDevicesMap[usbDevice];
        if (!vzDevice) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self errorWithMessage:NSLocalizedString(@"This USB device is connected to another virtual machine.", "UTMIOUSBHostManager")]);
            });
            return;
        }
        [self.connectedDevicesMap removeObjectForKey:usbDevice];
        usbDevice.uuid = nil;
        dispatch_async(self.vmQueue, ^{
            [firstController detachDevice:vzDevice completionHandler:^(NSError * _Nullable detachError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(detachError);
                });
            }];
        });
    });
}

- (void)restoreUsbDevice:(UTMIOUSBHostDevice *)usbDevice toVirtualMachineConfiguration:(VZVirtualMachineConfiguration *)virtualMachineConfiguration withCompletion:(void (^)(NSError * _Nullable error))completion {
    VZUSBControllerConfiguration *firstControllerConfig = virtualMachineConfiguration.usbControllers.firstObject;
    if (!firstControllerConfig) {
        completion([self errorWithMessage:NSLocalizedString(@"This virtual machine does not have any USB controllers.", "UTMIOUSBHostManager")]);
        return;
    }
    
    if (!usbDevice.uuid) {
        completion([self errorWithMessage:NSLocalizedString(@"Internal error: no identifier found for USB device.", "UTMIOUSBHostManager")]);
        return;
    }
    
    dispatch_async(gUsbHostManagerQueue, ^{
        UTMIOUSBHostDevice *matchedDevice = nil;
        for (UTMIOUSBHostDevice *device in gUsbDevices) {
            if ([usbDevice isEqual:device]) {
                matchedDevice = device;
                break;
            }
        }
        if (!matchedDevice) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self errorWithMessage:[NSString localizedStringWithFormat:NSLocalizedString(@"USB device not found or already in use: %@", "UTMIOUSBHostManager"), usbDevice.name]]);
            });
            return;
        }
        NSError *error = nil;
        id<VZUSBDeviceConfiguration> vzDeviceConfig = [self createVzUsbDeviceConfigFromUsbDevice:matchedDevice uuid:usbDevice.uuid error:&error];
        if (!vzDeviceConfig) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
            return;
        }
        
        if (IOServiceAuthorize(matchedDevice.ioService, kIOServiceInteractionAllowed) != kIOReturnSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self errorWithMessage:[NSString localizedStringWithFormat:NSLocalizedString(@"Failed to authorize USB device: %@", "UTMIOUSBHostManager"), usbDevice.name]]);
            });
            return;
        }
        
        NSArray *usbDevices = [firstControllerConfig.usbDevices arrayByAddingObject:vzDeviceConfig];
        firstControllerConfig.usbDevices = usbDevices;
        
        self.pendingDevicesMap[usbDevice.uuid] = matchedDevice;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
    });
}

- (NSArray<UTMIOUSBHostDevice *> *)connectedDevices {
    return self.connectedDevicesMap.allKeys;
}

- (void)synchronize {
    [self synchronizeWithVirtualMachine:nil];
}

- (void)synchronizeWithVirtualMachine:(nullable VZVirtualMachine *)virtualMachine {
    VZUSBController *firstController = virtualMachine.usbControllers.firstObject;
    NSArray<id<VZUSBDevice>> *usbDevices = firstController.usbDevices;
    if (firstController) {
        [self usbController:firstController setDelegate:self];
    }
    dispatch_async(gUsbHostManagerQueue, ^{
        for (id<VZUSBDevice> vzDevice in usbDevices) {
            UTMIOUSBHostDevice *device = self.pendingDevicesMap[vzDevice.uuid];
            if (device) {
                device.uuid = vzDevice.uuid;
                self.connectedDevicesMap[device] = vzDevice;
            }
        }
        [self.pendingDevicesMap removeAllObjects];
        
        NSMutableArray<UTMIOUSBHostDevice *> *toRemove = [NSMutableArray array];
        for (UTMIOUSBHostDevice *device in self.connectedDevicesMap) {
            id<VZUSBDevice> mappedVzDevice = self.connectedDevicesMap[device];
            if (![usbDevices containsObject:mappedVzDevice]) {
                [toRemove addObject:device];
            }
        }
        
        for (UTMIOUSBHostDevice *device in toRemove) {
            [self.connectedDevicesMap removeObjectForKey:device];
            device.uuid = nil;
            if ([self.delegate respondsToSelector:@selector(ioUsbHostManager:deviceRemoved:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate ioUsbHostManager:self deviceRemoved:device];
                });
            }
        }
    });
}

@end
