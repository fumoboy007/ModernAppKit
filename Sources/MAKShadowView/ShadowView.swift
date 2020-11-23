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

/// A container view that draws a rectangular shadow underneath its content view
/// in a performant manner.
public class ShadowView: NSView {
   // MARK: Shadow Cache

   private static let shadowCache = ShadowCache()

   // MARK: Disallowed NSView Properties

   public override var shadow: NSShadow? {
      get {
         return nil
      }

      set {
         preconditionFailure("Trying to set a shadow on the shadow view. This is probably not what you want.")
      }
   }

   // MARK: Shadow Properties

   /// The blur radius (in points) used to render the shadow.
   ///
   /// The default value is 3.
   public var shadowBlurRadius: CGFloat {
      get {
         return shadowImageProperties.shadowBlurRadius
      }

      set {
         shadowImageProperties.shadowBlurRadius = newValue
      }
   }

   /// The offset (in points) of the shadow relative to the content view.
   ///
   /// The default value is (0, -3).
   public var shadowOffset = NSSize(width: 0, height: -3) {
      didSet {
         needsLayout = true
         needsDisplay = true
      }
   }

   /// The color of the shadow.
   ///
   /// The default value is opaque black.
   public var shadowColor: NSColor {
      get {
         return shadowImageProperties.shadowColor
      }

      set {
         shadowImageProperties.shadowColor = newValue
      }
   }

   private var shadowImageProperties = ShadowCache.ShadowImageProperties(shadowBlurRadius: 3,
                                                                         shadowColor: NSColor.black) {
      didSet {
         guard shadowImageProperties != oldValue else {
            return
         }

         ShadowView.shadowCache.releaseShadowImage(with: oldValue)
         ShadowView.shadowCache.retainShadowImage(with: shadowImageProperties)

         needsLayout = true
         needsDisplay = true
      }
   }

   // MARK: Content View

   /// The view on top of the shadow.
   ///
   /// The content view must be rectangular and fully opaque in order for the shadow effect
   /// to look convincing.
   public var contentView: NSView? {
      didSet {
         guard contentView !== oldValue else {
            return
         }

         if let oldContentView = oldValue, oldContentView.superview === self {
            oldContentView.removeFromSuperview()
         }

         if let contentView = contentView {
            contentView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentView)
            NSLayoutConstraint.activate([
               contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
               contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
               contentView.topAnchor.constraint(equalTo: self.topAnchor),
               contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
         }
      }
   }

   public override var alignmentRectInsets: NSEdgeInsets {
      var insets = NSEdgeInsets(top: shadowBlurRadius,
                                left: shadowBlurRadius,
                                bottom: shadowBlurRadius,
                                right: shadowBlurRadius)

      if shadowOffset.width > 0 {
         insets.right += max(0, abs(shadowOffset.width) - insets.left)
         insets.left = max(0, insets.left - abs(shadowOffset.width))
      } else {
         insets.left += max(0, abs(shadowOffset.width) - insets.right)
         insets.right = max(0, insets.right - abs(shadowOffset.width))
      }

      if shadowOffset.height > 0 {
         insets.top += max(0, abs(shadowOffset.height) - insets.bottom)
         insets.bottom = max(0, insets.bottom - abs(shadowOffset.height))
      } else {
         insets.bottom += max(0, abs(shadowOffset.height) - insets.top)
         insets.top = max(0, insets.top - abs(shadowOffset.height))
      }

      return insets
   }

   // MARK: Initialization/Deinitialization

   public override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)

      commonInit()
   }

   private func commonInit() {
      wantsLayer = true
      layerContentsRedrawPolicy = .duringViewResize

      ShadowView.shadowCache.retainShadowImage(with: shadowImageProperties)
   }

   deinit {
      ShadowView.shadowCache.releaseShadowImage(with: shadowImageProperties)
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      static let shadowBlurRadius = "mo.darren.ModernAppKit.ShadowView.shadowBlurRadius"
      static let shadowOffsetWidth = "mo.darren.ModernAppKit.ShadowView.shadowOffsetWidth"
      static let shadowOffsetHeight = "mo.darren.ModernAppKit.ShadowView.shadowOffsetHeight"
      static let shadowColor = "mo.darren.ModernAppKit.ShadowView.shadowColor"
   }

   public required init?(coder: NSCoder) {
      super.init(coder: coder)

      commonInit()

      if coder.containsValue(forKey: CoderKey.shadowBlurRadius) {
         shadowBlurRadius = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowBlurRadius))
      }
      if coder.containsValue(forKey: CoderKey.shadowOffsetWidth) {
         shadowOffset.width = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowOffsetWidth))
      }
      if coder.containsValue(forKey: CoderKey.shadowOffsetHeight) {
         shadowOffset.height = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowOffsetHeight))
      }
      if let shadowColor = coder.decodeObject(forKey: CoderKey.shadowColor) as? NSColor {
         self.shadowColor = shadowColor
      }
   }

   public override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(Double(shadowBlurRadius), forKey: CoderKey.shadowBlurRadius)
      aCoder.encode(Double(shadowOffset.width), forKey: CoderKey.shadowOffsetWidth)
      aCoder.encode(Double(shadowOffset.height), forKey: CoderKey.shadowOffsetHeight)
      aCoder.encode(shadowColor, forKey: CoderKey.shadowColor)
   }

   // MARK: Updating the Layer

   public override var wantsUpdateLayer: Bool {
      return true
   }

   public override func updateLayer() {
      guard let layer = layer else {
         return
      }

      // I assume that the view will be redisplayed whenever the backing scale factor changes
      let scale = (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor) ?? 1.0
      let shadowImage = ShadowView.shadowCache.shadowImage(with: shadowImageProperties, scale: scale)

      layer.contents = shadowImage.layerContents(forContentsScale: scale)
      layer.contentsScale = scale

      var contentsRect = CGRect(x: shadowOffset.width > 0 ? shadowOffset.width : 0,
                                y: shadowOffset.height > 0 ? shadowOffset.height : 0,
                                width: bounds.width - abs(shadowOffset.width),
                                height: bounds.height - abs(shadowOffset.height))
      contentsRect.origin.x /= bounds.width
      contentsRect.origin.y /= bounds.height
      contentsRect.size.width /= bounds.width
      contentsRect.size.height /= bounds.height
      layer.contentsRect = contentsRect

      var contentsCenter = CGRect(origin: CGPoint.zero, size: shadowImage.size)
      contentsCenter.apply(shadowImage.capInsets)
      contentsCenter.origin.x /= shadowImage.size.width
      contentsCenter.origin.y /= shadowImage.size.height
      contentsCenter.size.width /= shadowImage.size.width
      contentsCenter.size.height /= shadowImage.size.height
      layer.contentsCenter = contentsCenter
   }

   // MARK: -

   fileprivate class ShadowCache {
      fileprivate struct ShadowImageProperties: Hashable {
         var shadowBlurRadius: CGFloat
         var shadowColor: NSColor
      }

      private class ImageContainer {
         var retainCount = 1
         var imageForScale = [CGFloat: NSImage]()
      }

      private var cache = [ShadowImageProperties: ImageContainer]()

      // MARK: Cache API

      func retainShadowImage(with imageProperties: ShadowImageProperties) {
         if let imageContainer = cache[imageProperties] {
            imageContainer.retainCount += 1
         } else {
            let imageContainer = ImageContainer()
            cache[imageProperties] = imageContainer
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

      func shadowImage(with imageProperties: ShadowImageProperties, scale: CGFloat) -> NSImage {
         guard let imageContainer = cache[imageProperties] else {
            preconditionFailure("Retain the shadow image before retrieving it.")
         }

         if let image = imageContainer.imageForScale[scale] {
            return image
         } else {
            let image = ShadowCache.makeShadowImage(with: imageProperties, scale: scale)
            imageContainer.imageForScale[scale] = image
            return image
         }
      }

      // MARK: Creating Shadow Images

      private static func makeShadowImage(with properties: ShadowImageProperties, scale: CGFloat) -> NSImage {
         // Because of the way gaussian blur works, the blurred border will have a thickness
         // of two times the blur radius. Therefore, our image size will need to be four times
         // the blur radius plus an extra pixel for the center. This will produce a normal
         // shadow.
         let imageSize = NSSize(width: properties.shadowBlurRadius * 4 * scale + 1,
                                height: properties.shadowBlurRadius * 4 * scale + 1)

         let shadow = NSShadow()
         shadow.shadowBlurRadius = properties.shadowBlurRadius * scale
         shadow.shadowOffset = NSSize(width: 0, height: imageSize.height)
         shadow.shadowColor = properties.shadowColor

         let image = NSImage(size: imageSize)
         image.capInsets = NSEdgeInsets(top: shadow.shadowBlurRadius * 2,
                                        left: shadow.shadowBlurRadius * 2,
                                        bottom: shadow.shadowBlurRadius * 2,
                                        right: shadow.shadowBlurRadius * 2)

         do {
            image.lockFocus()
            defer {
               image.unlockFocus()
            }

            shadow.set()

            let offscreenRect = NSRect(x: shadow.shadowBlurRadius,
                                       y: shadow.shadowBlurRadius - imageSize.height,
                                       width: imageSize.width - shadow.shadowBlurRadius * 2,
                                       height: imageSize.height - shadow.shadowBlurRadius * 2)

            NSColor.black.set()
            offscreenRect.fill()
         }

         return image
      }
   }
}
