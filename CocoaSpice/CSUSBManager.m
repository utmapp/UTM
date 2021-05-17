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

#import "CocoaSpice.h"
#import <glib.h>
#import <spice-client.h>

typedef enum {
    kUsbManagerCallConnect,
    kUsbManagerCallDisconnect
} usbManagerCall;

typedef struct {
    usbManagerCall call;
    SpiceUsbDeviceManager *manager;
    SpiceUsbDevice *device;
    gpointer callback;
} usbManagerData;

@interface CSUSBManager ()

@property (nonatomic, readwrite, nonnull) SpiceUsbDeviceManager *usbDeviceManager;

@end

@implementation CSUSBManager

#pragma mark - Signal callbacks

static void cs_device_error(SpiceUsbDeviceManager *manager,
                            SpiceUsbDevice        *device,
                            GError                *error,
                            gpointer               data)
{
    CSUSBManager *self = (__bridge CSUSBManager *)data;
    CSUSBDevice *usbdevice = [CSUSBDevice usbDeviceWithDevice:device];

    if (error->domain == G_IO_ERROR && error->code == G_IO_ERROR_CANCELLED)
        return;
    
    [self.delegate spiceUsbManager:self deviceError:[NSString stringWithUTF8String:error->message] forDevice:usbdevice];
}

static void cs_device_added(SpiceUsbDeviceManager *manager,
    SpiceUsbDevice *device, gpointer data)
{
    CSUSBManager *self = (__bridge CSUSBManager *)data;
    CSUSBDevice *usbdevice = [CSUSBDevice usbDeviceWithDevice:device];
    
    [self.delegate spiceUsbManager:self deviceAttached:usbdevice];
}

static void cs_device_removed(SpiceUsbDeviceManager *manager,
    SpiceUsbDevice *device, gpointer data)
{
    CSUSBManager *self = (__bridge CSUSBManager *)data;
    CSUSBDevice *usbdevice = [CSUSBDevice usbDeviceWithDevice:device];
    
    [self.delegate spiceUsbManager:self deviceRemoved:usbdevice];
}

static void cs_connect_cb(GObject *gobject, GAsyncResult *res, gpointer data)
{
    SpiceUsbDeviceManager *manager = SPICE_USB_DEVICE_MANAGER(gobject);
    CSUSBManagerConnectionCallback callback = (__bridge_transfer CSUSBManagerConnectionCallback)(data);
    GError *err = NULL;

    spice_usb_device_manager_connect_device_finish(manager, res, &err);
    if (err) {
        callback(NO, [NSString stringWithUTF8String:err->message]);
        g_error_free(err);
    } else {
        callback(YES, nil);
    }
}

static void cs_disconnect_cb(GObject *gobject, GAsyncResult *res, gpointer data)
{
    SpiceUsbDeviceManager *manager = SPICE_USB_DEVICE_MANAGER(gobject);
    CSUSBManagerConnectionCallback callback = (__bridge_transfer CSUSBManagerConnectionCallback)(data);
    GError *err = NULL;

    spice_usb_device_manager_disconnect_device_finish(manager, res, &err);
    if (err) {
        callback(NO, [NSString stringWithUTF8String:err->message]);
        g_error_free(err);
    } else {
        callback(YES, nil);
    }
}

static gboolean cs_call_manager(gpointer user_data)
{
    usbManagerData *data = (usbManagerData *)user_data;
    switch (data->call) {
        case kUsbManagerCallConnect:
            spice_usb_device_manager_connect_device_async(data->manager, data->device, NULL, cs_connect_cb, data->callback);
            break;
        case kUsbManagerCallDisconnect:
            spice_usb_device_manager_disconnect_device_async(data->manager, data->device, NULL, cs_disconnect_cb, data->callback);
            break;
        default:
            g_assert(0);
    }
    return G_SOURCE_REMOVE;
}

#pragma mark - Properties

- (BOOL)isAutoConnect {
    gboolean value;
    g_object_get(self.usbDeviceManager, "auto-connect", &value, NULL);
    return value;
}

- (void)setIsAutoConnect:(BOOL)isAutoConnect {
    g_object_set(self.usbDeviceManager, "auto-connect", isAutoConnect, NULL);
}

- (NSString *)autoConnectFilter {
    gchar *string;
    g_object_get(self.usbDeviceManager, "auto-connect-filter", &string, NULL);
    NSString *nsstring = [NSString stringWithUTF8String:string];
    g_free(string);
    return nsstring;
}

- (void)setAutoConnectFilter:(NSString *)autoConnectFilter {
    const gchar *string = [autoConnectFilter UTF8String];
    g_object_set(self.usbDeviceManager, "auto-connect-filter", string, NULL);
}

- (BOOL)isRedirectOnConnect {
    gboolean value;
    g_object_get(self.usbDeviceManager, "redirect-on-connect", &value, NULL);
    return value;
}

- (void)setIsRedirectOnConnect:(BOOL)isRedirectOnConnect {
    g_object_set(self.usbDeviceManager, "redirect-on-connect", isRedirectOnConnect, NULL);
}

- (NSInteger)numberFreeChannels {
    gint value;
    g_object_get(self.usbDeviceManager, "free-channels", &value, NULL);
    return value;
}

- (NSArray<CSUSBDevice *> *)usbDevices {
    NSMutableArray<CSUSBDevice *> *usbDevices = [NSMutableArray new];
    GPtrArray *arr = spice_usb_device_manager_get_devices(self.usbDeviceManager);
    if (arr != NULL) {
        for (int i = 0; i < arr->len; i++) {
            SpiceUsbDevice *device = g_ptr_array_index(arr, i);
            [usbDevices addObject:[CSUSBDevice usbDeviceWithDevice:device]];
        }
        g_ptr_array_unref(arr);
    }
    return usbDevices;
}

- (BOOL)isBusy {
    return spice_usb_device_manager_is_redirecting(self.usbDeviceManager);
}

#pragma mark - Construction

- (instancetype)initWithUsbDeviceManager:(SpiceUsbDeviceManager *)usbDeviceManager {
    if (self = [super init]) {
        self.usbDeviceManager = usbDeviceManager;
        g_signal_connect(usbDeviceManager, "auto-connect-failed",
                         G_CALLBACK(cs_device_error), GLIB_OBJC_RETAIN(self));
        g_signal_connect(usbDeviceManager, "device-error",
                         G_CALLBACK(cs_device_error), GLIB_OBJC_RETAIN(self));
        g_signal_connect(usbDeviceManager, "device-added",
                         G_CALLBACK(cs_device_added), GLIB_OBJC_RETAIN(self));
        g_signal_connect(usbDeviceManager, "device-removed",
                         G_CALLBACK(cs_device_removed), GLIB_OBJC_RETAIN(self));
    }
    return self;
}

- (void)dealloc {
    g_signal_handlers_disconnect_by_func(self.usbDeviceManager, G_CALLBACK(cs_device_error), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.usbDeviceManager, G_CALLBACK(cs_device_error), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.usbDeviceManager, G_CALLBACK(cs_device_added), GLIB_OBJC_RELEASE(self));
    g_signal_handlers_disconnect_by_func(self.usbDeviceManager, G_CALLBACK(cs_device_removed), GLIB_OBJC_RELEASE(self));
}

#pragma mark - Methods

- (BOOL)canRedirectUsbDevice:(CSUSBDevice *)usbDevice errorMessage:(NSString * _Nullable __autoreleasing *)errorMessage {
    GError *err = NULL;
    gboolean res = spice_usb_device_manager_can_redirect_device(self.usbDeviceManager, usbDevice.device, &err);
    if (errorMessage && err) {
        *errorMessage = [NSString stringWithUTF8String:err->message];
    }
    g_clear_error(&err);
    return res;
}

- (BOOL)isUsbDeviceConnected:(CSUSBDevice *)usbDevice {
    return spice_usb_device_manager_is_device_connected(self.usbDeviceManager, usbDevice.device);
}

- (void)spiceUsbManagerCall:(usbManagerCall)call forUsbDevice:(CSUSBDevice *)usbDevice withCompletion:(CSUSBManagerConnectionCallback)completion {
    usbManagerData *data = g_new0(usbManagerData, 1);
    data->call = call;
    data->manager = self.usbDeviceManager;
    data->device = usbDevice.device;
    data->callback = (__bridge_retained gpointer)completion;
    g_main_context_invoke_full([CSMain sharedInstance].glibMainContext,
                               G_PRIORITY_HIGH,
                               cs_call_manager,
                               data,
                               g_free);
}

- (void)connectUsbDevice:(CSUSBDevice *)usbDevice withCompletion:(CSUSBManagerConnectionCallback)completion {
    [self spiceUsbManagerCall:kUsbManagerCallConnect forUsbDevice:usbDevice withCompletion:completion];
}

- (void)disconnectUsbDevice:(CSUSBDevice *)usbDevice withCompletion:(CSUSBManagerConnectionCallback)completion {
    [self spiceUsbManagerCall:kUsbManagerCallDisconnect forUsbDevice:usbDevice withCompletion:completion];
}

@end
