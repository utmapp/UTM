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
#import "UTMTerminalIO.h"
#import "UTMConfiguration.h"

@interface UTMTerminalIO ()

@property (nonatomic, readwrite) BOOL isConnected;

@end

@implementation UTMTerminalIO

- (id)initWithConfiguration: (UTMConfiguration*) configuration {
    if (self = [super init]) {
        NSURL* terminalURL = [configuration terminalInputOutputURL];
        _terminal = [[UTMTerminal alloc] initWithURL: terminalURL];
    }
    
    return self;
}

- (void)dealloc {
    [self disconnect];
}

#pragma mark - UTMInputOutput

- (BOOL)startWithError:(NSError *__autoreleasing  _Nullable * _Nullable)err {
    // tell terminal to start listening to pipes
    return [_terminal connectWithError: err];
}

- (void)connectWithCompletion:(ioConnectCompletionHandler_t)block {
    // there's no connection to be made, so just return YES
    self.isConnected = YES;
    block(YES, nil);
}

- (void)disconnect {
    self.isConnected = NO;
    [_terminal disconnect];
}

- (UTMScreenshot *)screenshot {
    // MAIN THREAD ONLY
//    NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
//    paragraphStyle.alignment = NSTextAlignmentCenter;
//    UIFont* font = [UIFont systemFontOfSize: 18.0];
//    NSDictionary* strAttributes = @{
//        NSFontAttributeName: font,
//        NSForegroundColorAttributeName: [UIColor whiteColor],
//        NSParagraphStyleAttributeName: paragraphStyle
//    };
//
//    CGSize size = CGSizeMake(150.0f, 100.0f);
//    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    CGFloat color[] = {0, 0, 0};
//    CGContextSetFillColor(context, color);
//    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
//    NSString* text = @"Serial console";
//    CGFloat yOffset = (size.height - font.pointSize) / 2.0f;
//    [text drawInRect:CGRectMake(0.0, yOffset, size.width, [font pointSize]) withAttributes:strAttributes];
//    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//    return result;
    return nil;
}

- (void)syncViewState:(UTMViewState *)viewState {
}

- (void)restoreViewState:(UTMViewState *)viewState {
}

@end
