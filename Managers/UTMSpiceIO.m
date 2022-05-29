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

#import "UTMSpiceIO.h"
#import "UTMLegacyQemuConfiguration.h"
#import "UTMLegacyQemuConfiguration+Miscellaneous.h"
#import "UTMLegacyQemuConfiguration+Sharing.h"
#import "UTMQemuManager.h"
#import "UTMLogging.h"
#import "UTMViewState.h"
#import "UTM-Swift.h"

const int kMaxSpiceStartAttempts = 15; // qemu needs to start spice server first
const int64_t kSpiceStartRetryTimeout = (int64_t)1*NSEC_PER_SEC;
extern NSString *const kUTMErrorDomain;

@interface UTMSpiceIO ()

@property (nonatomic, readwrite, nullable) CSDisplay *primaryDisplay;
@property (nonatomic, readwrite, nullable) CSInput *primaryInput;
@property (nonatomic, readwrite, nullable) CSPort *primarySerial;
#if !defined(WITH_QEMU_TCI)
@property (nonatomic, readwrite, nullable) CSUSBManager *primaryUsbManager;
#endif
@property (nonatomic, nullable) CSConnection *spiceConnection;
@property (nonatomic, nullable) CSMain *spice;
@property (nonatomic, nullable, copy) NSURL *sharedDirectory;
@property (nonatomic) NSInteger port;
@property (nonatomic) BOOL dynamicResolutionSupported;
@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic) dispatch_queue_t connectQueue;
@property (nonatomic, nullable) void (^connectAttemptCallback)(void);
@property (nonatomic, nullable) void (^connectFinishedCallback)(UTMQemuManager *, CSConnectionError, NSError * _Nullable);

@end

@implementation UTMSpiceIO

- (instancetype)initWithConfiguration:(UTMLegacyQemuConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        self.connectQueue = dispatch_queue_create("SPICE Connect Attempt", NULL);
    }
    
    return self;
}

- (void)initializeSpiceIfNeeded {
    if (!self.spiceConnection) {
        self.spiceConnection = [[CSConnection alloc] initWithUnixSocketFile:self.configuration.spiceSocketURL];
        self.spiceConnection.delegate = self;
        self.spiceConnection.audioEnabled = _configuration.soundEnabled;
        self.spiceConnection.session.shareClipboard = _configuration.shareClipboardEnabled;
        self.spiceConnection.session.pasteboardDelegate = [UTMPasteboard generalPasteboard];
    }
}

#pragma mark - Actions

- (BOOL)startWithError:(NSError **)err {
    if (!self.spice) {
        self.spice = [CSMain sharedInstance];
    }
#ifdef SPICE_DEBUG_LOGGING
    [self.spice spiceSetDebug:YES];
#endif
    if (![self.spice spiceStart]) {
        if (err) {
            *err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to start SPICE client.", "UTMSpiceIO")}];
        }
        return NO;
    }
    [self initializeSpiceIfNeeded];
    
    return YES;
}

- (void)connectWithCompletion:(ioConnectCompletionHandler_t)block {
    __weak typeof(self) weakSelf = self;
    __block int attemptsLeft = kMaxSpiceStartAttempts;
    dispatch_async(self.connectQueue, ^{
        self.connectFinishedCallback = ^(UTMQemuManager *manager, CSConnectionError code, NSError *error) {
            typeof(self) _self = weakSelf;
            if (!_self) {
                return;
            }
            if (manager) {
                _self.connectAttemptCallback = nil;
                block(manager, nil);
            } else if (_self.connectAttemptCallback && code == kCSConnectionErrorConnect && attemptsLeft --> 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kSpiceStartRetryTimeout), _self.connectQueue, _self.connectAttemptCallback);
            } else {
                _self.connectAttemptCallback = nil;
                block(nil, error);
            }
        };
        self.connectAttemptCallback = ^{
            typeof(self) _self = weakSelf;
            if (!_self) {
                return;
            }
            if (![_self.spiceConnection connect]) {
                _self.connectFinishedCallback(nil, 0, [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Internal error trying to connect to SPICE server.", "UTMSpiceIO")}]);
            }
        };
        self.connectAttemptCallback();
    });
}

- (void)disconnect {
    dispatch_async(self.connectQueue, ^{
        if (self.connectFinishedCallback) {
            self.connectFinishedCallback(nil, 0, nil);
        }
    });
    [self endSharingDirectory];
    [self.spiceConnection disconnect];
    self.spiceConnection.delegate = nil;
    self.spiceConnection = nil;
    self.spice = nil;
    self.primaryDisplay = nil;
    self.primaryInput = nil;
#if !defined(WITH_QEMU_TCI)
    self.primaryUsbManager = nil;
#endif
}

- (CSScreenshot *)screenshot {
    return [self.primaryDisplay screenshot];
}

#pragma mark - CSConnectionDelegate

- (void)spiceConnected:(CSConnection *)connection {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    self.isConnected = YES;
#if !defined(WITH_QEMU_TCI)
    self.primaryUsbManager = connection.usbManager;
    [self.delegate spiceDidChangeUsbManager:connection.usbManager];
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
}

- (void)spiceError:(CSConnection *)connection code:(CSConnectionError)code message:(nullable NSString *)message {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    self.isConnected = NO;
    NSError *error = [NSError errorWithDomain:kUTMErrorDomain code:-code userInfo:@{NSLocalizedDescriptionKey: message}];
    dispatch_async(self.connectQueue, ^{
        if (self.connectFinishedCallback) {
            self.connectFinishedCallback(nil, code, error);
        }
    });
}

- (void)spiceDisplayCreatedOrUpdated:(CSConnection *)connection display:(CSDisplay *)display {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
    if (self.primaryDisplay == display) {
        [self.delegate spiceDidChangeDisplay:display];
    } else if (display.isPrimaryDisplay) {
        self.primaryDisplay = display;
        [self.delegate spiceDidCreateDisplay:display];
    }
}

- (void)spiceDisplayDestroyed:(CSConnection *)connection display:(CSDisplay *)display {
    NSAssert(connection == self.spiceConnection, @"Unknown connection");
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
        UTMQemuManager *manager = [[UTMQemuManager alloc] initWithPort:port];
        dispatch_async(self.connectQueue, ^{
            if (self.connectFinishedCallback) {
                self.connectFinishedCallback(manager, 0, nil);
            }
        });
    }
    if ([port.name isEqualToString:@"com.utmapp.terminal.0"]) {
        self.primarySerial = port;
        [self.delegate spiceDidCreateSerial:port];
    }
}

- (void)spiceForwardedPortClosed:(CSConnection *)connection port:(CSPort *)port {
    if ([port.name isEqualToString:@"org.qemu.monitor.qmp.0"]) {
    }
    if ([port.name isEqualToString:@"com.utmapp.terminal.0"]) {
        self.primarySerial = port;
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
        [self.spiceConnection.session setSharedDirectory:self.sharedDirectory.path readOnly:self.configuration.shareDirectoryReadOnly];
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
#if !defined(WITH_QEMU_TCI)
    if (self.primaryUsbManager) {
        [self.delegate spiceDidChangeUsbManager:self.primaryUsbManager];
    }
#endif
    if ([self.delegate respondsToSelector:@selector(spiceDynamicResolutionSupportDidChange:)]) {
        [self.delegate spiceDynamicResolutionSupportDidChange:self.dynamicResolutionSupported];
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
