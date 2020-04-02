/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "UTMRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "UTMShaderTypes.h"

// Main class performing the rendering
@implementation UTMRenderer
{
    // The device (aka GPU) we're using to render
    id<MTLDevice> _device;

    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    id<MTLRenderPipelineState> _pipelineState;

    // The command Queue from which we'll obtain command buffers
    id<MTLCommandQueue> _commandQueue;

    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
}

- (void)setSourceScreen:(id<UTMRenderSource>)source {
    source.device = _device;
    _sourceScreen = source;
}

- (void)setSourceCursor:(id<UTMRenderSource>)source {
    source.device = _device;
    _sourceCursor = source;
}

/// Initialize with the MetalKit view from which we'll obtain our Metal device
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        _device = mtkView.device;

        /// Create our render pipeline

        // Load all the shader files with a .metal file extension in the project
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Load the vertex function from the library
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Load the fragment function from the library
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Texturing Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;

        NSError *error = NULL;
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_pipelineState)
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state, error %@", error);
        }

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Create a translation+scale matrix
static matrix_float4x4 matrix_scale_translate(CGFloat scale, CGPoint translate)
{
    matrix_float4x4 m = {
        .columns[0] = {
            scale,
            0,
            0,
            0
        },
        .columns[1] = {
            0,
            scale,
            0,
            0
        },
        .columns[2] = {
            0,
            0,
            1,
            0
        },
        .columns[3] = {
            translate.x,
            -translate.y, // y flipped
            0,
            1
        }
        
    };
    return m;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    if (view.hidden) {
        return;
    }

    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        __weak dispatch_semaphore_t screenLock = nil;
        __weak dispatch_semaphore_t cursorLock = nil;

        // Create a render command encoder so we can render into something
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        if (self.sourceScreen && self.sourceScreen.visible) {
            // Lock screen updates
            bool hasAlpha = NO;
            screenLock = self.sourceScreen.drawLock;
            dispatch_semaphore_wait(screenLock, DISPATCH_TIME_FOREVER);
            
            // Render the screen first
            
            matrix_float4x4 transform = matrix_scale_translate(self.sourceScreen.viewportScale,
                                                               self.sourceScreen.viewportOrigin);

            [renderEncoder setRenderPipelineState:_pipelineState];

            [renderEncoder setVertexBuffer:self.sourceScreen.vertices
                                    offset:0
                                  atIndex:UTMVertexInputIndexVertices];

            [renderEncoder setVertexBytes:&_viewportSize
                                   length:sizeof(_viewportSize)
                                  atIndex:UTMVertexInputIndexViewportSize];

            [renderEncoder setVertexBytes:&transform
                                   length:sizeof(transform)
                                  atIndex:UTMVertexInputIndexTransform];

            [renderEncoder setVertexBytes:&hasAlpha
                                   length:sizeof(hasAlpha)
                                  atIndex:UTMVertexInputIndexHasAlpha];

            // Set the texture object.  The UTMTextureIndexBaseColor enum value corresponds
            ///  to the 'colorMap' argument in our 'samplingShader' function because its
            //   texture attribute qualifier also uses UTMTextureIndexBaseColor for its index
            [renderEncoder setFragmentTexture:self.sourceScreen.texture
                                      atIndex:UTMTextureIndexBaseColor];

            // Draw the vertices of our triangles
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:0
                              vertexCount:self.sourceScreen.numVertices];
        }

        if (self.sourceCursor && self.sourceCursor.visible) {
            // Lock cursor updates
            bool hasAlpha = YES;
            cursorLock = self.sourceCursor.drawLock;
            dispatch_semaphore_wait(cursorLock, DISPATCH_TIME_FOREVER);

            // Next render the cursor
            matrix_float4x4 transform = matrix_scale_translate(self.sourceScreen.viewportScale,
                                                               CGPointMake(self.sourceScreen.viewportOrigin.x +
                                                                           self.sourceCursor.viewportOrigin.x,
                                                                           self.sourceScreen.viewportOrigin.y +
                                                                           self.sourceCursor.viewportOrigin.y));
            [renderEncoder setVertexBuffer:self.sourceCursor.vertices
                                    offset:0
                                  atIndex:UTMVertexInputIndexVertices];
            [renderEncoder setVertexBytes:&_viewportSize
                                   length:sizeof(_viewportSize)
                                  atIndex:UTMVertexInputIndexViewportSize];
            [renderEncoder setVertexBytes:&transform
                                 length:sizeof(transform)
                                atIndex:UTMVertexInputIndexTransform];
            [renderEncoder setVertexBytes:&hasAlpha
                                 length:sizeof(hasAlpha)
                                atIndex:UTMVertexInputIndexHasAlpha];
            [renderEncoder setFragmentTexture:self.sourceCursor.texture
                                      atIndex:UTMTextureIndexBaseColor];
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:0
                              vertexCount:self.sourceCursor.numVertices];
        }

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
        
        // Release lock after GPU is done
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            // GPU work is complete
            // Signal the semaphore to start the CPU work
            if (screenLock) {
                dispatch_semaphore_signal(screenLock);
            }
            if (cursorLock) {
                dispatch_semaphore_signal(cursorLock);
            }
        }];
    }


    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

@end
