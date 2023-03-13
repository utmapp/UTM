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

#import "UTMQemuManager.h"
#import "qga-qapi-types.h"

NS_ASSUME_NONNULL_BEGIN

@class UTMQemuGuestAgentNetworkInterface;
@class UTMQemuGuestAgentExecStatus;

/// Interface with QEMU Guest Agent
@interface UTMQemuGuestAgent : UTMQemuManager

/// Attempt synchronization with guest agent
///
/// If an error is returned, any number of things could have happened including:
///   * Guest Agent has not started on the guest side
///   * Guest Agent has not been installed yet
///   * Guest Agent is too slow to respond
/// - Parameter completion: Callback to run on completion
- (void)synchronizeWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Set guest time
/// - Parameters:
///   - time: time in seconds, relative to the Epoch of 1970-01-01 in UTC.
///   - completion: Callback to run on completion
- (void)guestSetTime:(NSTimeInterval)time withCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Open a file in the guest and retrieve a file handle for it
/// - Parameters:
///   - path: Full path to the file in the guest to open.
///   - mode: open mode, as per fopen(), "r" is the default.
///   - completion: Callback to run on completion, returns file handle on success
- (void)guestFileOpen:(NSString *)path mode:(nullable NSString *)mode withCompletion:(void (^)(NSInteger, NSError * _Nullable))completion;

/// Close an open file in the guest
/// - Parameters:
///   - handle: filehandle returned by guest-file-open
///   - completion: Callback to run on completion
- (void)guestFileClose:(NSInteger)handle withCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Read from an open file in the guest.
///
/// As this command is just for limited, ad-hoc debugging, such as log
/// file access, the number of bytes to read is limited to 48 MB.
/// - Parameters:
///   - handle: filehandle returned by guest-file-open
///   - count: maximum number of bytes to read (maximum is 48MB)
///   - completion: Callback to run on completion, returns number of bytes read on success
- (void)guestFileRead:(NSInteger)handle count:(NSInteger)count withCompletion:(void (^)(NSData *, NSError * _Nullable))completion;

/// Write to an open file in the guest.
/// - Parameters:
///   - handle: filehandle returned by guest-file-open
///   - data: data to be written
///   - completion: Callback to run on completion, returns number of bytes written
- (void)guestFileWrite:(NSInteger)handle data:(NSData *)data withCompletion:(void (^)(NSInteger, NSError * _Nullable))completion;

/// Seek to a position in the file, as with fseek()
/// - Parameters:
///   - handle: filehandle returned by guest-file-open
///   - offset: bytes to skip over in the file stream
///   - whence: numeric code for interpreting offset
///   - completion: Callback to run on completion, returns current file position
- (void)guestFileSeek:(NSInteger)handle offset:(NSInteger)offset whence:(QGASeek)whence withCompletion:(void (^)(NSInteger, NSError * _Nullable))completion;

/// Write file changes buffered in userspace to disk/kernel buffers
/// - Parameters:
///   - handle: filehandle returned by guest-file-open
///   - completion: Callback to run on completion
- (void)guestFileFlush:(NSInteger)handle withCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;

/// Get list of guest IP addresses, MAC addresses and netmasks.
/// - Parameter completion: Callback to run on completion, returns list of network interfaces
- (void)guestNetworkGetInterfacesWithCompletion:(void (^)(NSArray<UTMQemuGuestAgentNetworkInterface *> *, NSError * _Nullable))completion;

/// Execute a command in the guest
/// - Parameters:
///   - path: path or executable name to execute
///   - argv: argument list to pass to executable
///   - envp: environment variables to pass to executable
///   - input: data to be passed to process stdin
///   - captureOutput: bool flag to enable capture of stdout/stderr of running process
///   - completion: Callback to run on completion, returns PID on success
- (void)guestExec:(NSString *)path argv:(nullable NSArray<NSString *> *)argv envp:(nullable NSArray<NSString *> *)envp input:(nullable NSData *)input captureOutput:(BOOL)captureOutput withCompletion:(void (^ _Nullable)(NSInteger, NSError * _Nullable))completion;

/// Check status of process associated with PID retrieved via guest-exec.
///
/// Reap the process and associated metadata if it has exited.
/// - Parameters:
///   - pid: returned from guest-exec
///   - completion: Callback to run on completion, returns status on success
- (void)guestExecStatus:(NSInteger)pid withCompletion:(void (^)(UTMQemuGuestAgentExecStatus *, NSError * _Nullable))completion;

@end

/// Represent a single network address
@interface UTMQemuGuestAgentNetworkAddress : NSObject

/// IP address
@property (nonatomic) NSString *ipAddress;

/// If true, `ipAddress` is a IPv6 address
@property (nonatomic) BOOL isIpV6Address;

/// Network prefix length
@property (nonatomic) NSInteger ipAddressPrefix;

+ (instancetype)networkAddressFromQapi:(GuestIpAddress *)qapi;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initFromQapi:(GuestIpAddress *)qapi NS_DESIGNATED_INITIALIZER;

@end

/// Represent a single network interface
@interface UTMQemuGuestAgentNetworkInterface : NSObject

/// The name of interface for which info are being delivered
@property (nonatomic) NSString *interfaceName;

/// Hardware address of this interface
@property (nonatomic, nullable) NSString *hardwareAddress;

/// List of addresses assigned
@property (nonatomic) NSArray<UTMQemuGuestAgentNetworkAddress *> *ipAddresses;

/// total bytes received
@property (nonatomic) NSInteger rxBytes;

/// total packets received
@property (nonatomic) NSInteger rxPackets;

/// bad packets received
@property (nonatomic) NSInteger rxErrors;

/// receiver dropped packets
@property (nonatomic) NSInteger rxDropped;

/// total bytes transmitted
@property (nonatomic) NSInteger txBytes;

/// total packets transmitted
@property (nonatomic) NSInteger txPackets;

/// packet transmit problems
@property (nonatomic) NSInteger txErrors;

/// dropped packets transmitted
@property (nonatomic) NSInteger txDropped;

+ (instancetype)networkInterfaceFromQapi:(GuestNetworkInterface *)qapi;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initFromQapi:(GuestNetworkInterface *)qapi NS_DESIGNATED_INITIALIZER;

@end

/// Return value of guestExecStatus
@interface UTMQemuGuestAgentExecStatus : NSObject

/// true if process has already terminated
@property (nonatomic) BOOL hasExited;

/// process exit code if it was normally terminated
@property (nonatomic) NSInteger exitCode;

/// signal number (linux) or unhandled exception code (windows) if the process was abnormally terminated.
@property (nonatomic) NSInteger signal;

/// stdout of the process
@property (nonatomic, nullable) NSData *outData;

/// stderr of the process
@property (nonatomic, nullable) NSData *errData;

/// true if stdout was not fully captured due to size limitation
@property (nonatomic) BOOL isOutDataTruncated;

/// true if stderr was not fully captured due to size limitation
@property (nonatomic) BOOL isErrDataTruncated;

+ (instancetype)execStatusFromQapi:(GuestExecStatus *)qapi;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initFromQapi:(GuestExecStatus *)qapi NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
