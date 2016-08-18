// MIT License
//
// Copyright © 2016 Darren Mo.
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

/// A layer-backed view with additional APIs for setting background color,
/// border width, border color, and corner radius. Use if you do not need
/// to do custom drawing.
open class LayerView: NSView {
   // MARK: Layer Properties

   public enum BorderWidth {
      case points(_: CGFloat)
      case pixels(_: CGFloat)
   }

   /// The background color of the view. Corresponds to the
   /// `backgroundColor` property of `CALayer`.
   ///
   /// The default value is no color.
   public var backgroundColor: NSColor? {
      didSet {
         needsDisplay = true
      }
   }

   /// The width of the border around the view. Corresponds to the
   /// `borderWidth` property of `CALayer`.
   ///
   /// The default value is 0.
   public var borderWidth = BorderWidth.points(0) {
      didSet {
         needsDisplay = true
      }
   }

   /// The color of the border around the view. Corresponds to the
   /// `borderColor` property of `CALayer`.
   ///
   /// The default value is opaque black.
   public var borderColor: NSColor? {
      didSet {
         needsDisplay = true
      }
   }

   /// The radius of the rounded corners of the view. Corresponds to the
   /// `cornerRadius` property of `CALayer`.
   ///
   /// The default value is 0.
   public var cornerRadius: CGFloat = 0 {
      didSet {
         needsDisplay = true
      }
   }

   // MARK: Initialization

   private static let backgroundColorCoderKey = "mo.darren.ModernAppKit.LayerView.backgroundColor"
   private static let isBorderWidthInPointsCoderKey = "mo.darren.ModernAppKit.LayerView.isBorderWidthInPoints"
   private static let borderWidthCoderKey = "mo.darren.ModernAppKit.LayerView.borderWidth"
   private static let borderColorCoderKey = "mo.darren.ModernAppKit.LayerView.borderColor"
   private static let cornerRadiusCoderKey = "mo.darren.ModernAppKit.LayerView.cornerRadius"

   public override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)

      wantsLayer = true
      layerContentsRedrawPolicy = .onSetNeedsDisplay
   }

   public required init?(coder: NSCoder) {
      self.backgroundColor = coder.decodeObject(forKey: LayerView.backgroundColorCoderKey) as? NSColor

      let isBorderWidthInPoints = coder.decodeBool(forKey: LayerView.isBorderWidthInPointsCoderKey)
      let borderWidth = CGFloat(coder.decodeDouble(forKey: LayerView.borderWidthCoderKey))
      if isBorderWidthInPoints {
         self.borderWidth = .points(borderWidth)
      } else {
         self.borderWidth = .pixels(borderWidth)
      }

      self.borderColor = coder.decodeObject(forKey: LayerView.borderColorCoderKey) as? NSColor
      self.cornerRadius = CGFloat(coder.decodeDouble(forKey: LayerView.cornerRadiusCoderKey))

      super.init(coder: coder)
   }

   open override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(backgroundColor, forKey: LayerView.backgroundColorCoderKey)

      switch borderWidth {
      case .points(let borderWidthInPoints):
         aCoder.encode(true, forKey: LayerView.isBorderWidthInPointsCoderKey)
         aCoder.encode(Double(borderWidthInPoints), forKey: LayerView.borderWidthCoderKey)

      case .pixels(let borderWidthInPixels):
         aCoder.encode(false, forKey: LayerView.isBorderWidthInPointsCoderKey)
         aCoder.encode(Double(borderWidthInPixels), forKey: LayerView.borderWidthCoderKey)
      }

      aCoder.encode(borderColor, forKey: LayerView.borderColorCoderKey)
      aCoder.encode(Double(cornerRadius), forKey: LayerView.cornerRadiusCoderKey)
   }

   // MARK: Updating the Layer

   open override var wantsUpdateLayer: Bool {
      return true
   }

   open override func updateLayer() {
      guard let layer = layer else {
         return
      }

      layer.backgroundColor = backgroundColor?.cgColor

      switch borderWidth {
      case .points(let borderWidthInPoints):
         layer.borderWidth = borderWidthInPoints

      case .pixels(let borderWidthInPixels):
         layer.borderWidth = borderWidthInPixels / layer.contentsScale
      }
      layer.borderColor = borderColor?.cgColor

      layer.cornerRadius = cornerRadius
   }
}
