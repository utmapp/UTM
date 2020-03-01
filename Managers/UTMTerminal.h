//
//  UTMTerminal.h
//  UTM
//
//  Created by Kacper Raczy on 29/02/2020.
//  Copyright © 2020 Kacper Raczy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UTMTerminalDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMTerminal : NSObject

@property (readonly) dispatch_queue_t queue;
@property (readonly, nullable) NSURL* pipeURL;
@property (weak, nullable) id<UTMTerminalDelegate> delegate;

- (BOOL)connectWithError: (NSError**) error;
- (void)disconnect;
- (void)sendInput: (NSString*) inputStr;

@end

NS_ASSUME_NONNULL_END
