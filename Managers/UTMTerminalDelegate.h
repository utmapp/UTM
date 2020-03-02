//
//  UTMTerminalDelegate.h
//  UTM
//
//  Created by Kacper Raczy on 29/02/2020.
//  Copyright © 2020 Kacper Raczy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UTMTerminal;

NS_ASSUME_NONNULL_BEGIN

@protocol UTMTerminalDelegate <NSObject>
- (void)terminal: (UTMTerminal*) terminal didReceiveData: (NSData*) data;
@end

NS_ASSUME_NONNULL_END
