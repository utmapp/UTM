/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for renderer class which performs Metal setup and per frame rendering
*/

#import "UTMRenderSource.h"
@import MetalKit;
@import CoreGraphics;

NS_ASSUME_NONNULL_BEGIN

// Our platform independent renderer class
@interface UTMRenderer : NSObject<MTKViewDelegate>

@property (nonatomic, weak, nullable) id<UTMRenderSource> sourceScreen;
@property (nonatomic, weak, nullable) id<UTMRenderSource> sourceCursor;

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;

@end

NS_ASSUME_NONNULL_END
