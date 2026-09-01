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

#import "UTMIOUSBHostDevice.h"
#import <IOKit/usb/IOUSBLib.h>

API_AVAILABLE(macos(15.0))
@interface UTMIOUSBHostDevice ()

@property (nonatomic, nullable, readwrite) NSString *usbManufacturerName;
@property (nonatomic, nullable, readwrite) NSString *usbProductName;
@property (nonatomic, nullable, readwrite) NSString *usbSerial;
@property (nonatomic, readwrite) NSInteger usbVendorId;
@property (nonatomic, readwrite) NSInteger usbProductId;
@property (nonatomic, readwrite) NSInteger usbBusNumber;
@property (nonatomic, readwrite) NSInteger usbPortNumber;
@property (nonatomic, readwrite) io_service_t ioService;
@property (nonatomic, nullable, readwrite) NSUUID *uuid;

@end

@implementation UTMIOUSBHostDevice

static NSString * _Nullable get_ioregistry_value_string(io_service_t service, CFStringRef property) {
    CFTypeRef cfProperty = IORegistryEntryCreateCFProperty(service, property, kCFAllocatorDefault, 0);
    if (cfProperty) {
        if (CFGetTypeID(cfProperty) == CFStringGetTypeID()) {
            return CFBridgingRelease(cfProperty);
        }
        CFRelease(cfProperty);
    }
    return nil;
}

static NSData * _Nullable get_ioregistry_value_data(io_service_t service, CFStringRef property) {
    CFTypeRef cfProperty = IORegistryEntryCreateCFProperty(service, property, kCFAllocatorDefault, 0);
    if (cfProperty) {
        if (CFGetTypeID(cfProperty) == CFDataGetTypeID()) {
            return CFBridgingRelease(cfProperty);
        }
        CFRelease(cfProperty);
    }
    return nil;
}

static BOOL get_ioregistry_value_number(io_service_t service, CFStringRef property, CFNumberType type, void *value) {
    BOOL ret = NO;
    CFTypeRef cfProperty = IORegistryEntryCreateCFProperty(service, property, kCFAllocatorDefault, 0);
    if (cfProperty) {
        if (CFGetTypeID(cfProperty) == CFNumberGetTypeID()) {
            ret = CFNumberGetValue((CFNumberRef)cfProperty, type, value);
        }
        CFRelease(cfProperty);
    }
    return ret;
}

static BOOL get_ioregistry_value_data_range(io_service_t service, CFStringRef property, CFIndex length, UInt8 *value) {
    BOOL ret = NO;
    CFTypeRef cfProperty = IORegistryEntryCreateCFProperty(service, property, kCFAllocatorDefault, 0);
    if (cfProperty) {
        if (CFGetTypeID(cfProperty) == CFDataGetTypeID() && CFDataGetLength((CFDataRef)cfProperty) >= length) {
            CFDataGetBytes((CFDataRef)cfProperty, CFRangeMake(0, length), value);
            ret = YES;
        }
        CFRelease(cfProperty);
    }
    return ret;
}

static BOOL get_device_port(io_service_t service, UInt8 *port) {
    io_service_t parent;
    BOOL ret = NO;

    if (get_ioregistry_value_number(service, CFSTR("PortNum"), kCFNumberSInt8Type, port)) {
        return YES;
    }

    if (IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == kIOReturnSuccess) {
        ret = get_ioregistry_value_data_range(parent, CFSTR("port"), 1, port);
        IOObjectRelease(parent);
    }

    return ret;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.usbManufacturerName forKey:@"usbManufacturerName"];
    [coder encodeObject:self.usbProductName forKey:@"usbProductName"];
    [coder encodeObject:self.usbSerial forKey:@"usbSerial"];
    [coder encodeInteger:self.usbVendorId forKey:@"usbVendorId"];
    [coder encodeInteger:self.usbProductId forKey:@"usbProductId"];
    [coder encodeInteger:self.usbBusNumber forKey:@"usbBusNumber"];
    [coder encodeInteger:self.usbPortNumber forKey:@"usbPortNumber"];
    [coder encodeObject:self.usbSignature forKey:@"usbSignature"];
    [coder encodeObject:self.uuid forKey:@"uuid"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _usbManufacturerName = [coder decodeObjectOfClass:[NSString class] forKey:@"usbManufacturerName"];
        _usbProductName = [coder decodeObjectOfClass:[NSString class] forKey:@"usbProductName"];
        _usbSerial = [coder decodeObjectOfClass:[NSString class] forKey:@"usbSerial"];
        _usbVendorId = [coder decodeIntegerForKey:@"usbVendorId"];
        _usbProductId = [coder decodeIntegerForKey:@"usbProductId"];
        _usbBusNumber = [coder decodeIntegerForKey:@"usbBusNumber"];
        _usbPortNumber = [coder decodeIntegerForKey:@"usbPortNumber"];
        _usbSignature = [coder decodeObjectOfClass:[NSData class] forKey:@"usbSignature"];
        _uuid = [coder decodeObjectForKey:@"uuid"];
    }
    return self;
}

- (instancetype)initWithService:(io_service_t)service {
    self = [super init];
    if (self) {
        _ioService = service;
        IOObjectRetain(service);
        
        _usbManufacturerName = get_ioregistry_value_string(service, CFSTR(kUSBVendorString));
        _usbProductName = get_ioregistry_value_string(service, CFSTR(kUSBProductString));
        _usbSerial = get_ioregistry_value_string(service, CFSTR(kUSBSerialNumberString));
        _usbSignature = get_ioregistry_value_data(service, CFSTR(kUSBHostDevicePropertySignature));
        
        UInt32 vendorId;
        if (get_ioregistry_value_number(service, CFSTR(kUSBVendorID), kCFNumberSInt32Type, &vendorId)) {
            _usbVendorId = vendorId;
        }
        
        UInt32 productId;
        if (get_ioregistry_value_number(service, CFSTR(kUSBProductID), kCFNumberSInt32Type, &productId)) {
            _usbProductId = productId;
        }
        
        UInt32 locationId;
        if (get_ioregistry_value_number(service, CFSTR(kUSBDevicePropertyLocationID), kCFNumberSInt32Type, &locationId)) {
            _usbBusNumber = locationId >> 24;
        }
        
        UInt8 port;
        if (get_device_port(service, &port)) {
            _usbPortNumber = port;
        }
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    UTMIOUSBHostDevice *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_usbManufacturerName = [self.usbManufacturerName copyWithZone:zone];
        copy->_usbProductName = [self.usbProductName copyWithZone:zone];
        copy->_usbSerial = [self.usbSerial copyWithZone:zone];
        copy->_usbVendorId = self.usbVendorId;
        copy->_usbProductId = self.usbProductId;
        copy->_usbBusNumber = self.usbBusNumber;
        copy->_usbPortNumber = self.usbPortNumber;
        copy->_usbSignature = [self.usbSignature copyWithZone:zone];
        copy->_ioService = self.ioService;
        if (copy->_ioService) {
            IOObjectRetain(copy->_ioService);
        }
        copy->_uuid = [self.uuid copyWithZone:zone];
    }
    return copy;
}

- (void)dealloc {
    if (_ioService) {
        IOObjectRelease(_ioService);
    }
}

- (NSString *)name {
    if (self.usbProductName) {
        return [NSString stringWithFormat:@"%@ (%ld:%ld)", self.usbProductName, (long)self.usbBusNumber, (long)self.usbPortNumber];
    } else {
        return nil;
    }
}

- (BOOL)isCaptured {
    return self.uuid != nil;
}

- (BOOL)isEqual:(id)other {
    if (self == other) return YES;
    if (![other isKindOfClass:[UTMIOUSBHostDevice class]]) return NO;
    UTMIOUSBHostDevice *device = (UTMIOUSBHostDevice *)other;
    // if both have UUID, compare that
    if (self.uuid != nil && device.uuid != nil) {
        return [self.uuid isEqual:device.uuid];
    }
    // next if both have a signature, compare that
    if (self.usbSignature != nil && device.usbSignature != nil) {
        return [self.usbSignature isEqualToData:device.usbSignature];
    }
    // otherwise, compare all the string values
    BOOL namesEqual = (self.usbManufacturerName == device.usbManufacturerName) || [self.usbManufacturerName isEqualToString:device.usbManufacturerName];
    BOOL productsEqual = (self.usbProductName == device.usbProductName) || [self.usbProductName isEqualToString:device.usbProductName];
    BOOL serialsEqual = (self.usbSerial == device.usbSerial) || [self.usbSerial isEqualToString:device.usbSerial];
    return namesEqual && productsEqual && serialsEqual &&
           self.usbVendorId == device.usbVendorId &&
           self.usbProductId == device.usbProductId &&
           self.usbBusNumber == device.usbBusNumber &&
           self.usbPortNumber == device.usbPortNumber;
}

- (NSUInteger)hash {
    if (self.uuid != nil) {
        return self.uuid.hash;
    }
    if (self.usbSignature != nil) {
        return self.usbSignature.hash;
    }
    return self.usbManufacturerName.hash ^ self.usbProductName.hash ^ self.usbSerial.hash ^ self.usbVendorId ^ self.usbProductId ^ self.usbBusNumber ^ self.usbPortNumber;
}

@end
