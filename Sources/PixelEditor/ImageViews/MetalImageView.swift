//
// Copyright (c) 2018 Muukii <muukii.app@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import MetalKit
import PixelEngine

open class MetalImageView : MTKView, HardwareImageViewType, MTKViewDelegate {
 
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private var image: CIImage?

  private lazy var commandQueue: MTLCommandQueue = { [unowned self] in
    return self.device!.makeCommandQueue()!
    }()

  private lazy var ciContext: CIContext = {
    [unowned self] in
    return CIContext(mtlDevice: self.device!)
    }()

  public override init(
    frame frameRect: CGRect,
    device: MTLDevice?
    ) {
    super.init(
      frame: frameRect,
      device: device ??
        MTLCreateSystemDefaultDevice()
    )
    if super.device == nil {
      fatalError("Device doesn't support Metal")
    }
    self.framebufferOnly = false
    self.delegate = self
    self.enableSetNeedsDisplay = true
    self.autoResizeDrawable = true
  }

  public required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func display(image: CIImage) {
    self.image = image
    setNeedsDisplay()
  }
  
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    
  }
  
  public func draw(in view: MTKView) {
    renderImage()
  }

  func renderImage() {
    guard
      let image = image,
      let targetTexture = currentDrawable?.texture else
    {
      return
    }
    
    #if DEBUG
    if image.cgImage != nil {
      EditorLog.debug("[MetalImageView] the backing storage of the image is in CPU, Render by metal might be slow.")
    }
    #endif

    let commandBuffer = commandQueue.makeCommandBuffer()

    let bounds = CGRect(
      origin: .zero,
      size: drawableSize
    )
    
    let fixedImage = image.transformed(by: .init(translationX: -image.extent.origin.x, y: -image.extent.origin.y))

    let targetRect = Geometry.rectThatAspectFill(
      aspectRatio: fixedImage.extent.size,
      minimumRect: bounds
    )

    let originX = targetRect.origin.x
    let originY = targetRect.origin.y
    let scaleX = targetRect.width / fixedImage.extent.width
    let scaleY = targetRect.height / fixedImage.extent.height
    let scale = min(scaleX, scaleY)
    let scaledImage = fixedImage
      .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
      .transformed(by: CGAffineTransform(translationX: originX, y: originY))

    ciContext.render(
      scaledImage,
      to: targetTexture,
      commandBuffer: commandBuffer,
      bounds: bounds,
      colorSpace: fixedImage.colorSpace ?? colorSpace
    )

    commandBuffer?.present(currentDrawable!)
    commandBuffer?.commit()
  }
}

