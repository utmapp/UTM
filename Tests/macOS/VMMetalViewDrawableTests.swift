//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

import XCTest
import MetalKit
import CocoaSpiceRenderer
@testable import UTM

/// A QEMU display window draws each frame from `VMMetalView.drawDisplayLinkFrame()` (macOS 14 and later).
/// A frame drawn into a drawable of another size than the view's pixels is scaled into the window, which
/// blurs the guest's display (#8191). These tests draw frames the way the window does, without a VM.
@MainActor
final class VMMetalViewDrawableTests: XCTestCase {
    /// Records the drawable of each frame, then lets `renderer` draw it (or clears it).
    private final class RecordingDelegate: NSObject, MTKViewDelegate {
        let commandQueue: MTLCommandQueue
        weak var renderer: CSMetalRenderer?
        /// Pixel size of each frame's drawable
        var sizes: [CGSize] = []
        /// Pixels of the last frame `renderer` drew
        var lastPixels: [UInt32] = []

        init(device: MTLDevice, renderer: CSMetalRenderer? = nil) {
            commandQueue = device.makeCommandQueue()!
            self.renderer = renderer
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else {
                return
            }
            sizes.append(CGSize(width: drawable.texture.width, height: drawable.texture.height))
            if let renderer = renderer {
                renderer.draw(in: view)
                lastPixels = copyPixels(of: drawable.texture, behindWorkOn: renderer.commandQueue)
            } else if let pass = view.currentRenderPassDescriptor,
                      let commandBuffer = commandQueue.makeCommandBuffer(),
                      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }

        /// Copies a drawable's texture out on the queue the renderer drew it on, so the copy runs after that
        /// draw, while the drawable is still held here
        private func copyPixels(of texture: MTLTexture, behindWorkOn queue: MTLCommandQueue) -> [UInt32] {
            let count = texture.width * texture.height
            guard let buffer = queue.device.makeBuffer(length: count * 4, options: .storageModeShared),
                  let commandBuffer = queue.makeCommandBuffer(),
                  let blit = commandBuffer.makeBlitCommandEncoder() else {
                return []
            }
            blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOriginMake(0, 0, 0),
                      sourceSize: MTLSizeMake(texture.width, texture.height, 1),
                      to: buffer, destinationOffset: 0, destinationBytesPerRow: texture.width * 4, destinationBytesPerImage: 0)
            blit.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return Array(UnsafeBufferPointer(start: buffer.contents().assumingMemoryBound(to: UInt32.self), count: count))
        }
    }

    /// A guest display: a texture and the quad CocoaSpice builds for it (`CSDisplay.rebuildDisplayVertices`).
    private final class TestRenderSource: NSObject, CSRenderSource {
        let texture: MTLTexture?
        let vertices: MTLBuffer?
        let numVertices: UInt = 6
        let isVisible = true
        let offset = CGPoint.zero
        let hasAlpha = false
        let isInverted = false
        weak var cursor: CSRenderSource?

        init(device: MTLDevice, width: Int, height: Int, pixels: [UInt32]) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            let texture = device.makeTexture(descriptor: descriptor)!
            pixels.withUnsafeBytes { bytes in
                texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
            }
            self.texture = texture
            let w = Float(width) / 2, h = Float(height) / 2
            let quad: [CSRenderVertex] = [
                CSRenderVertex(position: [ w,  h], textureCoordinate: [1, 0]),
                CSRenderVertex(position: [-w,  h], textureCoordinate: [0, 0]),
                CSRenderVertex(position: [-w, -h], textureCoordinate: [0, 1]),
                CSRenderVertex(position: [ w,  h], textureCoordinate: [1, 0]),
                CSRenderVertex(position: [-w, -h], textureCoordinate: [0, 1]),
                CSRenderVertex(position: [ w, -h], textureCoordinate: [1, 1]),
            ]
            vertices = device.makeBuffer(bytes: quad, length: MemoryLayout<CSRenderVertex>.stride * quad.count)
        }
    }

    private var window: NSWindow?

    override func tearDown() {
        window?.close()
        window = nil
        super.tearDown()
    }

    /// A view set up as `VMDisplayQemuMetalWindowController` sets it up when a display link draws it.
    private func makeView(points: CGSize) throws -> VMMetalView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("This host has no Metal device.")
        }
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: points), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        self.window = window
        let view = VMMetalView(frame: window.contentView!.bounds, device: device)
        view.autoresizingMask = [.width, .height]
        view.framebufferOnly = false
        view.isPaused = true
        window.contentView!.addSubview(view)
        return view
    }

    /// Draws one frame, or skips the test on a host that gives the view no drawable.
    private func drawFrame(_ view: VMMetalView, recordedBy delegate: RecordingDelegate) throws {
        let count = delegate.sizes.count
        view.drawDisplayLinkFrame()
        if delegate.sizes.count == count {
            throw XCTSkip("This host gives the view no drawable.")
        }
    }

    private func pixelSize(of view: NSView) -> CGSize {
        view.convertToBacking(view.bounds).size
    }

    /// Runs the main queue until the blocks queued on it so far have run.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    func testFramesAreDrawnAtTheViewsPixelSizeAfterResizing() throws {
        let view = try makeView(points: CGSize(width: 400, height: 300))
        let delegate = RecordingDelegate(device: view.device!)
        view.delegate = delegate
        for points in [CGSize(width: 400, height: 300), CGSize(width: 640, height: 400), CGSize(width: 320, height: 200)] {
            window!.setContentSize(points)
            try drawFrame(view, recordedBy: delegate)
            XCTAssertEqual(delegate.sizes.last, pixelSize(of: view), "frame after resizing to \(points) points")
        }
    }

    /// The guest's pixels reach the window unchanged at 1:1 (Retina mode on a Retina screen, or any mode
    /// at scale 1): a one-pixel checkerboard comes back exactly, so any resampling on the way fails.
    func testOneToOneFrameKeepsEveryGuestPixel() throws {
        let (width, height) = (64, 48)
        // the window opens at another size and is then fitted to the guest, as a VM window is
        let view = try makeView(points: CGSize(width: 400, height: 300))
        let scale = window!.backingScaleFactor
        let device = view.device!
        let renderer = CSMetalRenderer(metalKitView: view)
        let delegate = RecordingDelegate(device: device, renderer: renderer)
        view.delegate = delegate
        try drawFrame(view, recordedBy: delegate)
        window!.setContentSize(CGSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale))
        XCTAssertEqual(pixelSize(of: view), CGSize(width: width, height: height))
        renderer.viewportScale = 1.0

        let white: UInt32 = 0xFFFF_FFFF, black: UInt32 = 0xFF00_0000
        let pattern = (0..<height).flatMap { y in (0..<width).map { x in (x + y) % 2 == 0 ? white : black } }
        let source = TestRenderSource(device: device, width: width, height: height, pixels: pattern)
        let drawn = expectation(description: "frame drawn")
        renderer.invalidateRenderSource(source) { drawn.fulfill() }
        drainMainQueue()
        try drawFrame(view, recordedBy: delegate)
        wait(for: [drawn], timeout: 5)

        XCTAssertEqual(delegate.sizes.last, CGSize(width: width, height: height))
        let mismatches = zip(delegate.lastPixels, pattern).filter { $0 != $1 }.count + abs(delegate.lastPixels.count - pattern.count)
        XCTAssertEqual(mismatches, 0, "\(mismatches) of \(pattern.count) pixels differ from the guest's")
    }
}
