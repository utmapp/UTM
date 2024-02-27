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

#import "UTMLogging.h"
#if !defined(WITH_REMOTE)
@import QEMUKitInternal;
#endif

static UTMLogging *gLoggingInstance;

void UTMLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:[format stringByAppendingString:@"\n"] arguments:args];
    va_end(args);
    [[UTMLogging sharedInstance] writeLine:line];
}

@implementation UTMLogging

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        gLoggingInstance = [[UTMLogging alloc] init];
    }
}

+ (UTMLogging *)sharedInstance {
    return gLoggingInstance;
}

- (void)writeLine:(NSString *)line {
#if defined(WITH_REMOTE)
    NSLog(@"%@", line);
#else
    [QEMULogging.sharedInstance writeLine:line];
#endif
}

@end
