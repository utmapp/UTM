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

@property (nonatomic, readonly) NSURL* outPipeURL;
@property (nonatomic, readonly) NSURL* inPipeURL;
@property (nonatomic, weak, nullable) id<UTMTerminalDelegate> delegate;

- (id)initWithURL: (NSURL*) url;
- (BOOL)connectWithError: (NSError** _Nullable) error;
- (void)disconnect;
- (BOOL)isConnected;
- (void)sendInput: (NSString*) inputStr;

@end

NS_ASSUME_NONNULL_END
