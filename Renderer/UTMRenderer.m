/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "UTMRenderer.h"
#import "UTMLogging.h"

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
    
    // Sampler object
    id<MTLSamplerState> _sampler;
}

- (void)setSource:(id<UTMRenderSource>)source {
    source.device = _device;
    _source = source;
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
            UTMLog(@"Failed to created pipeline state, error %@", error);
        }

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        
        // Sampler
        [self changeUpscaler:MTLSamplerMinMagFilterLinear downscaler:MTLSamplerMinMagFilterLinear];
    }

    return self;
}

/// Scalers from VM settings
- (void)changeUpscaler:(MTLSamplerMinMagFilter)upscaler downscaler:(MTLSamplerMinMagFilter)downscaler {
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = downscaler;
    samplerDescriptor.magFilter = upscaler;
     
    _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
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
    id<UTMRenderSource> source = self.source;
    if (view.hidden || !source) {
        return;
    }

    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder so we can render into something
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        // Lock screen updates
        dispatch_semaphore_t drawLock = source.drawLock;
        dispatch_semaphore_wait(drawLock, DISPATCH_TIME_FOREVER);
        
        // Render the screen first
        
        bool hasAlpha = NO;
        matrix_float4x4 transform = matrix_scale_translate(source.viewportScale,
                                                           source.viewportOrigin);

        [renderEncoder setRenderPipelineState:_pipelineState];

        [renderEncoder setVertexBuffer:source.displayVertices
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
        [renderEncoder setFragmentTexture:source.displayTexture
                                  atIndex:UTMTextureIndexBaseColor];
        
        [renderEncoder setFragmentSamplerState:_sampler
                                       atIndex:UTMSamplerIndexTexture];

        // Draw the vertices of our triangles
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:source.displayNumVertices];
        
        // Draw cursor
        if (source.cursorVisible) {
            // Next render the cursor
            bool hasAlpha = YES;
            matrix_float4x4 transform = matrix_scale_translate(source.viewportScale,
                                                               CGPointMake(source.viewportOrigin.x +
                                                                           source.cursorOrigin.x,
                                                                           source.viewportOrigin.y +
                                                                           source.cursorOrigin.y));
            [renderEncoder setVertexBuffer:source.cursorVertices
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
            [renderEncoder setFragmentTexture:source.cursorTexture
                                      atIndex:UTMTextureIndexBaseColor];
            [renderEncoder setFragmentSamplerState:_sampler
                                           atIndex:UTMSamplerIndexTexture];
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:0
                              vertexCount:source.cursorNumVertices];
        }

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
        
        // Release lock after GPU is done
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            // GPU work is complete
            // Signal the semaphore to start the CPU work
            dispatch_semaphore_signal(drawLock);
        }];
    }


    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

@end
