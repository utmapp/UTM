//
// Copyright © 2022 osy. All rights reserved.
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

#import <glib.h>
#import "UTMSpiceIO.h"
#import "UTM-Swift.h"

NSString *const kUTMErrorDomain = @"com.utmapp.utm";

@interface UTMSpiceIO ()

@property (nonatomic, nullable) NSURL *socketUrl;
@property (nonatomic, nullable) NSString *host;
@property (nonatomic) NSInteger tlsPort;
@property (nonatomic, nullable) NSData *serverPublicKey;
@property (nonatomic, nullable) NSString *password;
@property (nonatomic) UTMSpiceIOOptions options;
@property (nonatomic, readwrite, nullable) CSDisplay *primaryDisplay;
@property (nonatomic) NSMutableArray<CSDisplay *> *mutableDisplays;
@property (nonatomic, readwrite, nullable) CSInput *primaryInput;
@property (nonatomic, readwrite, nullable) CSPort *primarySerial;
@property (nonatomic) NSMutableArray<CSPort *> *mutableSerials;
#if defined(WITH_USB)
@property (nonatomic, readwrite, nullable) CSUSBManager *primaryUsbManager;
#endif
@property (nonatomic, nullable) CSConnection *spiceConnection;
@property (nonatomic, nullable) CSMain *spice;
@property (nonatomic, nullable, copy) NSURL *sharedDirectory;
@property (nonatomic) BOOL dynamicResolutionSupported;
@property (nonatomic, readwrite) BOOL isConnected;

@end

@implementation UTMSpiceIO

@synthesize connectDelegate;

- (NSArray<CSDisplay *> *)displays {
    return self.mutableDisplays;
}

- (NSArray<CSPort *> *)serials {
    return self.mutableSerials;
}

- (LogHandler_t)logHandler {
    return CSMain.sharedInstance.logHandler;
}

- (void)setLogHandler:(LogHandler_t)logHandler {
    CSMain.sharedInstance.logHandler = logHandler;
}

- (instancetype)initWithSocketUrl:(NSURL *)socketUrl options:(UTMSpiceIOOptions)options {
    if (self = [super init]) {
        self.socketUrl = socketUrl;
        self.options = options;
        self.mutableDisplays = [NSMutableArray array];
        self.mutableSerials = [NSMutableArray array];
    }
    
    return self;
}

- (instancetype)initWithHost:(NSString *)host tlsPort:(NSInteger)tlsPort serverPublicKey:(NSData *)serverPublicKey password:(NSString *)password options:(UTMSpiceIOOptions)options {
    if (self = [super init]) {
        self.host = host;
        self.tlsPort = tlsPort;
        self.serverPublicKey = serverPublicKey;
        self.password = password;
        self.options = options;
        self.mutableDisplays = [NSMutableArray array];
        self.mutableSerials = [NSMutableArray array];
    }

    return self;
}

- (void)initializeSpiceIfNeeded {
    if (!self.spiceConnection) {
        if (self.socketUrl) {
            NSURL *relativeSocketFile = [NSURL fileURLWithPath:self.socketUrl.lastPathComponent];
            self.spiceConnection = [[CSConnection alloc] initWithUnixSocketFile:relativeSocketFile];
        } else {
            self.spiceConnection = [[CSConnection alloc] initWithHost:self.host tlsPort:[@(self.tlsPort) stringValue] serverPublicKey:self.serverPublicKey];
            self.spiceConnection.password = self.password;
        }
        self.spiceConnection.delegate = self;
        self.spiceConnection.audioEnabled = (self.options & UTMSpiceIOOptionsHasAudio) == UTMSpiceIOOptionsHasAudio;
        self.spiceConnection.session.shareClipboard = (self.options & UTMSpiceIOOptionsHasClipboardSharing) == UTMSpiceIOOptionsHasClipboardSharing;
        self.spiceConnection.session.pasteboardDelegate = [UTMPasteboard generalPasteboard];
    }
}

#pragma mark - Actions

- (BOOL)startWithError:(NSError * _Nullable *)error {
    if (!self.spice) {
        self.spice = [CSMain sharedInstance];
    }
    if ((self.options & UTMSpiceIOOptionsHasDebugLog) == UTMSpiceIOOptionsHasDebugLog) {
        [self.spice spiceSetDebug:YES];
    }
    // do not need to encode/decode audio locally
    g_setenv("SPICE_DISABLE_OPUS", "1", YES);
    if (self.socketUrl) {
        // need to chdir to workaround AF_UNIX sun_len limitations
        NSString *curdir = self.socketUrl.URLByDeletingLastPathComponent.path;
        if (!curdir || ![NSFileManager.defaultManager changeCurrentDirectoryPath:curdir]) {
            if (error) {
                *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to change current directory.", "UTMSpiceIO")}];
            }
            return NO;
        }
    }
    if (![self.spice spiceStart]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to start SPICE client.", "UTMSpiceIO")}];
        }
        return NO;
    }
    [self initializeSpiceIfNeeded];
    
    return YES;
}

- (BOOL)connectWithError:(NSError * _Nullable *)error {
    if (![self.spiceConnection connect]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Internal error trying to connect to SPICE server.", "UTMSpiceIO")}];
        }
        return NO;
    } else {
        return YES;
    }
}

- (void)disconnect {
    [self endSharingDirectory];
    [self.spiceConnection disconnect];
    self.spiceConnection.delegate = nil;
    self.spiceConnection = nil;
    self.spice = nil;
    self.primaryDisplay = nil;
    [self.mutableDisplays removeAllObjects];
    self.primaryInput = nil;
    self.primarySerial = nil;
    [self.mutableSerials removeAllObjects];
#if defined(WITH_USB)
    self.primaryUsbManager = nil;
#endif
}

- (void)screenshotWithCompletion:(screenshotCallback_t)completion {
    CSDisplay *primaryDisplay = self.primaryDisplay;
    if (primaryDisplay) {
        [self.primaryDisplay screenshotWithCompletion:completion];
    } else {
        completion(nil);
    }
}

#pragma mark - CSConnectionDelegate

- (void)spiceConnected:(CSConnection *)connection {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    self.isConnected = YES;
#if defined(WITH_USB)
    self.primaryUsbManager = connection.usbManager;
    [self.delegate spiceDidChangeUsbManager:connection.usbManager];
#endif
#if defined(WITH_REMOTE)
    [self.connectDelegate remoteInterfaceDidConnect:self];
#endif
}

- (void)spiceInputAvailable:(CSConnection *)connection input:(CSInput *)input {
    if (self.primaryInput == nil) {
        self.primaryInput = input;
        [self.delegate spiceDidCreateInput:input];
    }
}

- (void)spiceInputUnavailable:(CSConnection *)connection input:(CSInput *)input {
    if (self.primaryInput == input) {
        self.primaryInput = nil;
        [self.delegate spiceDidDestroyInput:input];
    }
}

- (void)spiceDisconnected:(CSConnection *)connection {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    self.isConnected = NO;
    if ([self.delegate respondsToSelector:@selector(spiceDidDisconnect)]) {
        [self.delegate spiceDidDisconnect];
    }
}

- (void)spiceError:(CSConnection *)connection code:(CSConnectionError)code message:(nullable NSString *)message {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    self.isConnected = NO;
#if defined(WITH_REMOTE)
    [self.connectDelegate remoteInterface:self didErrorWithMessage:message];
#else
    [self.connectDelegate qemuInterface:self didErrorWithMessage:message];
#endif
}

- (void)spiceDisplayCreated:(CSConnection *)connection display:(CSDisplay *)display {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    if (display.isPrimaryDisplay) {
        self.primaryDisplay = display;
    }
    [self.mutableDisplays addObject:display];
    [self.delegate spiceDidCreateDisplay:display];
}

- (void)spiceDisplayUpdated:(CSConnection *)connection display:(CSDisplay *)display {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    [self.delegate spiceDidUpdateDisplay:display];
}

- (void)spiceDisplayDestroyed:(CSConnection *)connection display:(CSDisplay *)display {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    [self.mutableDisplays removeObject:display];
    if (self.primaryDisplay == display) {
        self.primaryDisplay = nil;
    }
    [self.delegate spiceDidDestroyDisplay:display];
}

- (void)spiceAgentConnected:(CSConnection *)connection supportingFeatures:(CSConnectionAgentFeature)features {
    self.dynamicResolutionSupported = (features & kCSConnectionAgentFeatureMonitorsConfig) != kCSConnectionAgentFeatureNone;
}

- (void)spiceAgentDisconnected:(CSConnection *)connection {
    self.dynamicResolutionSupported = NO;
}

- (void)spiceForwardedPortOpened:(CSConnection *)connection port:(CSPort *)port {
    if ([port.name isEqualToString:@"org.qemu.monitor.qmp.0"]) {
#if !defined(WITH_REMOTE)
        UTMQemuPort *qemuPort = [[UTMQemuPort alloc] initFrom:port];
        [self.connectDelegate qemuInterface:self didCreateMonitorPort:qemuPort];
#endif
    }
    if ([port.name isEqualToString:@"org.qemu.guest_agent.0"]) {
#if !defined(WITH_REMOTE)
        UTMQemuPort *qemuPort = [[UTMQemuPort alloc] initFrom:port];
        [self.connectDelegate qemuInterface:self didCreateGuestAgentPort:qemuPort];
#endif
    }
    if ([port.name isEqualToString:@"com.utmapp.terminal.0"]) {
        self.primarySerial = port;
    }
    if ([port.name hasPrefix:@"com.utmapp.terminal."]) {
        [self.mutableSerials addObject:port];
        [self.delegate spiceDidCreateSerial:port];
    }
}

- (void)spiceForwardedPortClosed:(CSConnection *)connection port:(CSPort *)port {
    if ([port.name isEqualToString:@"org.qemu.monitor.qmp.0"]) {
    }
    if ([port.name isEqualToString:@"org.qemu.guest_agent.0"]) {
    }
    if ([port.name hasPrefix:@"com.utmapp.terminal."]) {
        [self.mutableSerials removeObject:port];
        if (self.primarySerial == port) {
            self.primarySerial = nil;
        }
        [self.delegate spiceDidDestroySerial:port];
    }
}

#pragma mark - Shared Directory

- (void)changeSharedDirectory:(NSURL *)url {
    if (self.sharedDirectory) {
        [self endSharingDirectory];
    }
    self.sharedDirectory = url;
    [self startSharingDirectory];
}

- (void)startSharingDirectory {
    if (self.sharedDirectory) {
        UTMLog(@"setting share directory to %@", self.sharedDirectory.path);
        [self.sharedDirectory startAccessingSecurityScopedResource];
        [self.spiceConnection.session setSharedDirectory:self.sharedDirectory.path readOnly:(self.options & UTMSpiceIOOptionsIsShareReadOnly) == UTMSpiceIOOptionsIsShareReadOnly];
    }
}

- (void)endSharingDirectory {
    if (self.sharedDirectory) {
        [self.sharedDirectory stopAccessingSecurityScopedResource];
        self.sharedDirectory = nil;
        UTMLog(@"ended share directory sharing");
    }
}

#pragma mark - Properties

- (void)setDelegate:(id<UTMSpiceIODelegate>)delegate {
    _delegate = delegate;
    // make sure to send initial data
    if (self.primaryInput) {
        [self.delegate spiceDidCreateInput:self.primaryInput];
    }
    if (self.primaryDisplay) {
        [self.delegate spiceDidCreateDisplay:self.primaryDisplay];
    }
    if (self.primarySerial) {
        [self.delegate spiceDidCreateSerial:self.primarySerial];
    }
#if defined(WITH_USB)
    if (self.primaryUsbManager) {
        [self.delegate spiceDidChangeUsbManager:self.primaryUsbManager];
    }
#endif
    if ([self.delegate respondsToSelector:@selector(spiceDynamicResolutionSupportDidChange:)]) {
        [self.delegate spiceDynamicResolutionSupportDidChange:self.dynamicResolutionSupported];
    }
    for (CSDisplay *display in self.mutableDisplays) {
        if (display != self.primaryDisplay) {
            [self.delegate spiceDidCreateDisplay:display];
        }
    }
    for (CSPort *port in self.mutableSerials) {
        if (port != self.primarySerial) {
            [self.delegate spiceDidCreateSerial:port];
        }
    }
}

- (void)setDynamicResolutionSupported:(BOOL)dynamicResolutionSupported {
    if (_dynamicResolutionSupported != dynamicResolutionSupported) {
        if ([self.delegate respondsToSelector:@selector(spiceDynamicResolutionSupportDidChange:)]) {
            [self.delegate spiceDynamicResolutionSupportDidChange:dynamicResolutionSupported];
        }
    }
    _dynamicResolutionSupported = dynamicResolutionSupported;
}

@end
