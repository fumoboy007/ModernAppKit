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

/// A layer-backed view with additional APIs for setting background color, border width, border color, and corner radius.
///
/// Use if you do not need to do custom drawing.
///
/// Supports animations.
open class LayerView: NSView {
   // MARK: Layer Properties

   public enum BorderWidth: Equatable {
      case points(CGFloat)
      case pixels(CGFloat)

      func inPoints(usingScale contentsScale: CGFloat) -> CGFloat {
         switch self {
         case .points(let borderWidthInPoints):
            return borderWidthInPoints

         case .pixels(let borderWidthInPixels):
            return borderWidthInPixels / contentsScale
         }
      }

      func inPixels(usingScale contentsScale: CGFloat) -> CGFloat {
         switch self {
         case .points(let borderWidthInPoints):
            return borderWidthInPoints * contentsScale

         case .pixels(let borderWidthInPixels):
            return borderWidthInPixels
         }
      }
   }

   /// The background color of the view.
   ///
   /// The default value is no color.
   ///
   /// Animatable.
   ///
   /// - Remark: Corresponds to the `CALayer.backgroundColor` property.
   @objc
   public dynamic var backgroundColor = NSColor.clear {
      didSet {
         needsDisplay = true
      }
   }

   /// The width of the border around the view.
   ///
   /// The default value is 0.
   ///
   /// To animate, use `animatableBorderWidthInPoints` or
   /// `animatableBorderWidthInPixels`.
   ///
   /// - Remark: Corresponds to the `CALayer.borderWidth` property.
   ///
   /// - Remark: Since `BorderWidth` is an enum with associated values, `borderWidth` cannot be a
   ///           dynamic Objective-C property, which is a requirement for animations. Therefore, we need to
   ///           maintain two separate dynamic Objective-C properties.
   public var borderWidth: BorderWidth {
      get {
         return _borderWidth
      }

      set {
         _borderWidth = newValue

         // Stop animations.
         willChangeValue(forKey: "animatableBorderWidthInPoints")
         didChangeValue(forKey: "animatableBorderWidthInPoints")
         willChangeValue(forKey: "animatableBorderWidthInPixels")
         didChangeValue(forKey: "animatableBorderWidthInPixels")
      }
   }
   private var _borderWidth = BorderWidth.points(0) {
      didSet {
         needsDisplay = true
      }
   }

   /// An animatable version of the `borderWidth` property. Values
   /// are in points.
   ///
   /// The `fromValue` of the animation will be automatically set
   /// to the current value of `borderWidth`.
   ///
   /// - Remark: This property cannot automatically be kept in sync with the other border width
   ///           properties (except at the start of an animation) due to a dependency cycle.
   @objc
   public dynamic var animatableBorderWidthInPoints: CGFloat = 0 {
      didSet {
         _borderWidth = .points(animatableBorderWidthInPoints)
      }
   }

   /// An animatable version of the `borderWidth` property. Values
   /// are in pixels.
   ///
   /// The `fromValue` of the animation will be automatically set
   /// to the current value of `borderWidth`.
   ///
   /// - Remark: This property cannot automatically be kept in sync with the other border width
   ///           properties (except at the start of an animation) due to a dependency cycle.
   @objc
   public dynamic var animatableBorderWidthInPixels: CGFloat = 0 {
      didSet {
         _borderWidth = .pixels(animatableBorderWidthInPixels)
      }
   }

   private var contentsScale: CGFloat = 1.0

   /// The color of the border around the view.
   ///
   /// The default value is opaque black.
   ///
   /// Animatable.
   ///
   /// - Remark: Corresponds to the `CALayer.borderColor` property.
   @objc
   public dynamic var borderColor = NSColor.black {
      didSet {
         needsDisplay = true
      }
   }

   /// The radius of the rounded corners of the view.
   ///
   /// The default value is 0.
   ///
   /// Animatable.
   ///
   /// - Remark: Corresponds to the `CALayer.cornerRadius` property.
   @objc
   public dynamic var cornerRadius: CGFloat = 0 {
      didSet {
         needsDisplay = true
      }
   }

   // MARK: Initialization

   public override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)

      commonInit()
   }

   private func commonInit() {
      wantsLayer = true
      layerContentsRedrawPolicy = .onSetNeedsDisplay
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      private static let prefix = "mo.darren.ModernAppKit.LayerView"

      static let backgroundColor = "\(prefix).backgroundColor"
      static let isBorderWidthInPoints = "\(prefix).isBorderWidthInPoints"
      static let borderWidth = "\(prefix).borderWidth"
      static let borderColor = "\(prefix).borderColor"
      static let cornerRadius = "\(prefix).cornerRadius"
   }

   public required init?(coder: NSCoder) {
      if let backgroundColor = coder.decodeObject(of: NSColor.self, forKey: CoderKey.backgroundColor) {
         self.backgroundColor = backgroundColor
      }

      if coder.containsValue(forKey: CoderKey.isBorderWidthInPoints) &&
         coder.containsValue(forKey: CoderKey.borderWidth) {
         let isBorderWidthInPoints = coder.decodeBool(forKey: CoderKey.isBorderWidthInPoints)
         let borderWidth = CGFloat(coder.decodeDouble(forKey: CoderKey.borderWidth))
         if isBorderWidthInPoints {
            self._borderWidth = .points(borderWidth)
         } else {
            self._borderWidth = .pixels(borderWidth)
         }
      }

      if let borderColor = coder.decodeObject(of: NSColor.self, forKey: CoderKey.borderColor) {
         self.borderColor = borderColor
      }

      if coder.containsValue(forKey: CoderKey.cornerRadius) {
         self.cornerRadius = CGFloat(coder.decodeDouble(forKey: CoderKey.cornerRadius))
      }

      super.init(coder: coder)

      commonInit()
   }

   open override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(backgroundColor, forKey: CoderKey.backgroundColor)

      switch borderWidth {
      case .points(let borderWidthInPoints):
         aCoder.encode(true, forKey: CoderKey.isBorderWidthInPoints)
         aCoder.encode(Double(borderWidthInPoints), forKey: CoderKey.borderWidth)

      case .pixels(let borderWidthInPixels):
         aCoder.encode(false, forKey: CoderKey.isBorderWidthInPoints)
         aCoder.encode(Double(borderWidthInPixels), forKey: CoderKey.borderWidth)
      }

      aCoder.encode(borderColor, forKey: CoderKey.borderColor)
      aCoder.encode(Double(cornerRadius), forKey: CoderKey.cornerRadius)
   }

   // MARK: Updating the Layer

   open override var wantsUpdateLayer: Bool {
      return true
   }

   open override func updateLayer() {
      guard let layer = layer else {
         return
      }

      layer.backgroundColor = backgroundColor.cgColor

      layer.borderWidth = borderWidth.inPoints(usingScale: contentsScale)
      layer.borderColor = borderColor.cgColor

      layer.cornerRadius = cornerRadius
   }

   open override func viewDidChangeBackingProperties() {
      super.viewDidChangeBackingProperties()

      contentsScale = window?.backingScaleFactor ?? 1.0
   }

   // MARK: Animations

   open override class func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
      switch key {
      case "backgroundColor",
           "animatableBorderWidthInPoints",
           "animatableBorderWidthInPixels",
           "borderColor",
           "cornerRadius":
         return CABasicAnimation(keyPath: key)

      default:
         return super.defaultAnimation(forKey: key)
      }
   }

   open override func animation(forKey key: NSAnimatablePropertyKey) -> Any? {
      guard let animation = super.animation(forKey: key) else {
         return nil
      }

      switch key {
      case "animatableBorderWidthInPoints":
         guard let basicAnimation = animation as? CABasicAnimation,
               basicAnimation.fromValue == nil else {
            break
         }
         // Set `fromValue` to current `borderWidth` value, which may be
         // different from current `animatableBorderWidthInPoints` value
         // because the border width properties are not automatically
         // kept in sync with each other.
         basicAnimation.fromValue = borderWidth.inPoints(usingScale: contentsScale)

      case "animatableBorderWidthInPixels":
         guard let basicAnimation = animation as? CABasicAnimation,
               basicAnimation.fromValue == nil else {
            break
         }
         // Set `fromValue` to current `borderWidth` value, which may be
         // different from current `animatableBorderWidthInPixels` value
         // because the border width properties are not automatically
         // kept in sync with each other.
         basicAnimation.fromValue = borderWidth.inPixels(usingScale: contentsScale)

      default:
         break
      }

      return animation
   }
}
