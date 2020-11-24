// MIT License
//
// Copyright © 2016-2020 Darren Mo.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Cocoa

class ShadowCache {
   // MARK: Private Properties

   private class ImageContainer {
      let image: NSImage

      var retainCount = 1
      #if DEBUG
      var renderCount = 0
      #endif

      init(image: NSImage) {
         self.image = image
      }
   }

   private var cache = [ShadowImageProperties: ImageContainer]()

   // MARK: Initialization

   static let shared = ShadowCache()

   private init() {
   }

   // MARK: Cache API

   func retainShadowImage(with imageProperties: ShadowImageProperties) -> NSImage {
      if let imageContainer = cache[imageProperties] {
         imageContainer.retainCount += 1

         return imageContainer.image
      } else {
         let image = makeShadowImage(with: imageProperties)

         let imageContainer = ImageContainer(image: image)
         cache[imageProperties] = imageContainer

         return image
      }
   }

   func releaseShadowImage(with imageProperties: ShadowImageProperties) {
      guard let imageContainer = cache[imageProperties] else {
         preconditionFailure("Trying to over-release shadow image.")
      }

      imageContainer.retainCount -= 1
      if imageContainer.retainCount == 0 {
         cache[imageProperties] = nil
      }
   }

   #if DEBUG
   func retainCountForShadowImage(with imageProperties: ShadowImageProperties) -> Int {
      return cache[imageProperties]?.retainCount ?? 0
   }

   func renderCountForShadowImage(with imageProperties: ShadowImageProperties) -> Int {
      return cache[imageProperties]?.renderCount ?? 0
   }
   #endif

   // MARK: Creating Shadow Images

   private func makeShadowImage(with properties: ShadowImageProperties) -> NSImage {
      // Because of the way gaussian blur works, the blur will have a thickness of two times
      // the blur radius (centered on the border). Therefore, our image size will need to be
      // four times the blur radius plus an extra point for the center. This will produce a
      // normal shadow.
      let imageSize = NSSize(width: properties.shadowBlurRadius * 4 + 1,
                             height: properties.shadowBlurRadius * 4 + 1)
      let capInsets = NSEdgeInsets(top: properties.shadowBlurRadius * 2,
                                   left: properties.shadowBlurRadius * 2,
                                   bottom: properties.shadowBlurRadius * 2,
                                   right: properties.shadowBlurRadius * 2)

      let image = NSImage(size: imageSize, flipped: false) { [weak self] destinationRect in
         let shadow = NSShadow()
         shadow.shadowBlurRadius = properties.shadowBlurRadius
         shadow.shadowOffset = NSSize(width: 0,
                                      height: destinationRect.height)
         shadow.shadowColor = properties.shadowColor

         shadow.set()

         let offscreenRect = NSRect(x: shadow.shadowBlurRadius,
                                    y: shadow.shadowBlurRadius - destinationRect.height,
                                    width: destinationRect.width - shadow.shadowBlurRadius * 2,
                                    height: destinationRect.height - shadow.shadowBlurRadius * 2)

         NSColor.black.set()
         offscreenRect.fill()

         #if DEBUG
         self?.didRenderShadowImage(with: properties)
         #endif

         return true
      }
      image.capInsets = capInsets

      return image
   }

   #if DEBUG
   private func didRenderShadowImage(with properties: ShadowImageProperties) {
      cache[properties]?.renderCount += 1
   }
   #endif
}
