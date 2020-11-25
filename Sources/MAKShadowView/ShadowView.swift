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
         needsUpdateConstraints = true
         needsLayout = true
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

   private var shadowImageProperties = ShadowImageProperties(shadowBlurRadius: 3,
                                                             shadowColor: NSColor.black) {
      didSet {
         guard shadowImageProperties != oldValue else {
            return
         }

         ShadowCache.shared.releaseShadowImage(with: oldValue)
         shadowImageView.image = ShadowCache.shared.retainShadowImage(with: shadowImageProperties)

         needsUpdateConstraints = true
         needsLayout = true
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

         configureContentView()
         configureShadowImageView()
      }
   }

   private func configureContentView() {
      guard let contentView = contentView else {
         return
      }

      addSubview(contentView)
      contentView.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
         contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
         contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
         contentView.topAnchor.constraint(equalTo: self.topAnchor),
         contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
      ])
   }

   // MARK: Initialization/Deinitialization

   public override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)

      commonInit()
   }

   private func commonInit() {
      configureContentView()

      shadowImageView.image = ShadowCache.shared.retainShadowImage(with: shadowImageProperties)
      configureShadowImageView()
   }

   deinit {
      ShadowCache.shared.releaseShadowImage(with: shadowImageProperties)
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      private static let prefix = "mo.darren.ModernAppKit.ShadowView"

      static let shadowBlurRadius = "\(prefix).shadowBlurRadius"
      static let shadowOffsetWidth = "\(prefix).shadowOffsetWidth"
      static let shadowOffsetHeight = "\(prefix).shadowOffsetHeight"
      static let shadowColor = "\(prefix).shadowColor"

      static let contentView = "\(prefix).contentView"
      static let shadowImageView = "\(prefix).shadowImageView"
   }

   public required init?(coder: NSCoder) {
      if coder.containsValue(forKey: CoderKey.shadowBlurRadius) {
         shadowImageProperties.shadowBlurRadius = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowBlurRadius))
      }
      if coder.containsValue(forKey: CoderKey.shadowOffsetWidth) {
         shadowOffset.width = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowOffsetWidth))
      }
      if coder.containsValue(forKey: CoderKey.shadowOffsetHeight) {
         shadowOffset.height = CGFloat(coder.decodeDouble(forKey: CoderKey.shadowOffsetHeight))
      }
      if let shadowColor = coder.decodeObject(of: NSColor.self, forKey: CoderKey.shadowColor) {
         shadowImageProperties.shadowColor = shadowColor
      }
      if let contentView = coder.decodeObject(of: NSView.self, forKey: CoderKey.contentView) {
         self.contentView = contentView
      }

      super.init(coder: coder)

      if let oldShadowImageView = coder.decodeObject(of: NSView.self, forKey: CoderKey.shadowImageView) {
         // We do not want to serialize the shadow image view but `NSView.encode(with:)` serializes all
         // subviews. Therefore, we need to remove the old shadow image view that was deserialized by
         // `NSView.init(coder:)`.
         oldShadowImageView.removeFromSuperview()
      }

      commonInit()
   }

   public override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(Double(shadowBlurRadius), forKey: CoderKey.shadowBlurRadius)
      aCoder.encode(Double(shadowOffset.width), forKey: CoderKey.shadowOffsetWidth)
      aCoder.encode(Double(shadowOffset.height), forKey: CoderKey.shadowOffsetHeight)
      aCoder.encode(shadowColor, forKey: CoderKey.shadowColor)
      aCoder.encode(contentView, forKey: CoderKey.contentView)
      aCoder.encode(shadowImageView, forKey: CoderKey.shadowImageView)
   }

   // MARK: Shadow Image View

   private let shadowImageView: NSImageView = {
      let shadowImageView = NSImageView()
      shadowImageView.wantsLayer = true
      shadowImageView.imageScaling = .scaleAxesIndependently

      return shadowImageView
   }()

   private var shadowImageViewXOffsetConstraint: NSLayoutConstraint?
   private var shadowImageViewYOffsetConstraint: NSLayoutConstraint?
   private var shadowImageViewWidthConstraint: NSLayoutConstraint?
   private var shadowImageViewHeightConstraint: NSLayoutConstraint?

   private func configureShadowImageView() {
      shadowImageView.removeFromSuperview()
      shadowImageViewXOffsetConstraint = nil
      shadowImageViewYOffsetConstraint = nil
      shadowImageViewWidthConstraint = nil
      shadowImageViewHeightConstraint = nil

      guard let contentView = contentView else {
         return
      }

      addSubview(shadowImageView,
                 positioned: .below,
                 relativeTo: contentView)
      shadowImageView.translatesAutoresizingMaskIntoConstraints = false

      let shadowImageViewXOffsetConstraint = shadowImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
      self.shadowImageViewXOffsetConstraint = shadowImageViewXOffsetConstraint

      let shadowImageViewYOffsetConstraint = contentView.bottomAnchor.constraint(equalTo: shadowImageView.bottomAnchor)
      self.shadowImageViewYOffsetConstraint = shadowImageViewYOffsetConstraint

      let shadowImageViewWidthConstraint = shadowImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
      self.shadowImageViewWidthConstraint = shadowImageViewWidthConstraint

      let shadowImageViewHeightConstraint = shadowImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor)
      self.shadowImageViewHeightConstraint = shadowImageViewHeightConstraint

      updateShadowImageViewConstraints()

      NSLayoutConstraint.activate([
         shadowImageViewXOffsetConstraint,
         shadowImageViewYOffsetConstraint,
         shadowImageViewWidthConstraint,
         shadowImageViewHeightConstraint
      ])
   }

   // MARK: Layout

   public override func updateConstraints() {
      updateShadowImageViewConstraints()

      super.updateConstraints()
   }

   private func updateShadowImageViewConstraints() {
      shadowImageViewXOffsetConstraint?.constant = shadowOffset.width - shadowBlurRadius
      shadowImageViewYOffsetConstraint?.constant = shadowOffset.height - shadowBlurRadius
      shadowImageViewWidthConstraint?.constant = shadowBlurRadius * 2
      shadowImageViewHeightConstraint?.constant = shadowBlurRadius * 2
   }

   public override var alignmentRectInsets: NSEdgeInsets {
      let contentRect = NSRect.zero

      var shadowRect = contentRect
      shadowRect.origin.x += shadowOffset.width - shadowBlurRadius
      shadowRect.origin.y += shadowOffset.height - shadowBlurRadius
      shadowRect.size.width += shadowBlurRadius * 2
      shadowRect.size.height += shadowBlurRadius * 2

      let enclosingRect = contentRect.union(shadowRect)
      return NSEdgeInsets(top: enclosingRect.maxY - contentRect.maxY,
                          left: contentRect.minX - enclosingRect.minX,
                          bottom: contentRect.minY - enclosingRect.minY,
                          right: enclosingRect.maxX - contentRect.maxX)
   }
}
