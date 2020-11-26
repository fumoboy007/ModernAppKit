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
import MAKEagerTextStorage

/// An `NSTextView` subclass that implements `intrinsicContentSize` so that the text view
/// can participate in layout outside of a scroll view.
///
/// - Attention: The text storage must be an instance of `EagerTextStorage`.
/// - Attention: The layout manager must be an instance of `EagerLayoutManager`.
open class AutoLayoutTextView: NSTextView {
   // MARK: Text Components

   public override class var stronglyReferencesTextStorage: Bool {
      return true
   }

   private static func areTextComponentTypesCorrect(in textContainer: NSTextContainer?) -> Bool {
      if let layoutManager = textContainer?.layoutManager {
         guard layoutManager is EagerLayoutManager else {
            return false
         }

         if let textStorage = layoutManager.textStorage {
            guard textStorage is EagerTextStorage else {
               return false
            }
         }
      }

      return true
   }

   // MARK: Initialization/Deinitialization

   public override convenience init(frame frameRect: NSRect) {
      self.init(frame: frameRect,
                textContainer: AutoLayoutTextView.makeDefaultTextContainer(textViewWidth: frameRect.width))
   }

   public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
      precondition(AutoLayoutTextView.areTextComponentTypesCorrect(in: container))

      super.init(frame: frameRect, textContainer: container)

      setTextViewDefaults()
   }

   private func setTextViewDefaults() {
      minSize = NSSize.zero
      maxSize = NSSize(width: CGFloat.infinity, height: CGFloat.infinity)
      isHorizontallyResizable = false
      isVerticallyResizable = false
   }

   private static func makeDefaultTextContainer(textViewWidth: CGFloat) -> NSTextContainer {
      let textContainer = NSTextContainer(size: NSSize(width: textViewWidth, height: CGFloat.infinity))
      textContainer.widthTracksTextView = true
      textContainer.heightTracksTextView = false
      textContainer.lineFragmentPadding = 0

      let textStorage = EagerTextStorage()
      let layoutManager = EagerLayoutManager()

      textStorage.addLayoutManager(layoutManager)
      layoutManager.addTextContainer(textContainer)

      return textContainer
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      private static let prefix = "mo.darren.ModernAppKit.AutoLayoutTextView"

      static let isAutoLayoutTextView = "\(prefix).isAutoLayoutTextView"
   }

   private enum DeserializationError: Error {
      case failedToRecreateLayoutManager(underlyingError: Error?)
      case incorrectTextComponentTypes
   }

   public required init?(coder: NSCoder) {
      super.init(coder: coder)

      // The serialized data may have been created using a superclass instead of an `AutoLayoutTextView`
      // instance. For example, an `AutoLayoutTextView` created in Interface Builder using the “Text View”
      // element would be initialized with the serialized data for `NSTextView`.
      if !coder.decodeBool(forKey: CoderKey.isAutoLayoutTextView) {
         if let textContainer = textContainer {
            // If a text container exists, then the superclass is `NSTextView`. We need to replace the
            // text storage and layout manager with instances of `EagerTextStorage` and `EagerLayoutManager`,
            // respectively.

            do {
               try AutoLayoutTextView.replaceTextComponents(in: textContainer)
            } catch {
               coder.failWithError(error)
               return nil
            }
         } else {
            // If a text container does not exist, then the superclass is `NSView`. We should set up the
            // default text components.

            let textContainer = AutoLayoutTextView.makeDefaultTextContainer(textViewWidth: frame.width)
            textContainer.textView = self

            setTextViewDefaults()
         }
      }

      guard AutoLayoutTextView.areTextComponentTypesCorrect(in: textContainer) else {
         coder.failWithError(DeserializationError.incorrectTextComponentTypes)
         return nil
      }
   }

   open override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(true, forKey: CoderKey.isAutoLayoutTextView)
   }

   private static func replaceTextComponents(in textContainer: NSTextContainer) throws {
      let textStorage: EagerTextStorage
      if let oldTextStorage = textContainer.layoutManager?.textStorage {
         textStorage = EagerTextStorage(attributedString: oldTextStorage)
      } else {
         textStorage = EagerTextStorage()
      }

      let layoutManager: EagerLayoutManager
      if let oldLayoutManager = textContainer.layoutManager {
         oldLayoutManager.replaceTextStorage(textStorage)
         layoutManager = try makeEagerLayoutManager(from: oldLayoutManager)
      } else {
         layoutManager = EagerLayoutManager()
         textStorage.addLayoutManager(layoutManager)
         layoutManager.addTextContainer(textContainer)
      }
   }

   private static func makeEagerLayoutManager(from layoutManager: NSLayoutManager) throws -> EagerLayoutManager {
      do {
         let textContainers = layoutManager.textContainers
         for textContainerIndex in (0..<textContainers.count).reversed() {
            layoutManager.removeTextContainer(at: textContainerIndex)
         }

         let textStorage = layoutManager.textStorage
         textStorage?.removeLayoutManager(layoutManager)

         let serializedData = try NSKeyedArchiver.archivedData(withRootObject: layoutManager,
                                                               requiringSecureCoding: false)

         let unarchiver = try NSKeyedUnarchiver(forReadingFrom: serializedData)
         defer {
            unarchiver.finishDecoding()
         }

         unarchiver.requiresSecureCoding = false

         let archivedClassName =
            layoutManager.classForKeyedArchiver.map { String(cString: class_getName($0)) } ??
            layoutManager.className
         unarchiver.setClass(EagerLayoutManager.self,
                             forClassName: archivedClassName)

         guard let eagerLayoutManager = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) as? EagerLayoutManager else {
            throw DeserializationError.failedToRecreateLayoutManager(underlyingError: nil)
         }

         textStorage?.addLayoutManager(eagerLayoutManager)
         for textContainer in textContainers {
            eagerLayoutManager.addTextContainer(textContainer)
         }

         return eagerLayoutManager
      } catch {
         throw DeserializationError.failedToRecreateLayoutManager(underlyingError: error)
      }
   }

   // MARK: Intrinsic Content Size

   /// Called when the layout manager completes layout.
   ///
   /// The default implementation of this method invalidates the intrinsic content size.
   open func didCompleteLayout() {
      invalidateIntrinsicContentSize()
   }

   open override func invalidateIntrinsicContentSize() {
      _intrinsicContentSize = nil
      super.invalidateIntrinsicContentSize()
   }

   private var _intrinsicContentSize: NSSize?
   open override var intrinsicContentSize: NSSize {
      if let intrinsicContentSize = _intrinsicContentSize {
         return intrinsicContentSize
      } else {
         let intrinsicContentSize = calculateIntrinsicContentSize()
         _intrinsicContentSize = intrinsicContentSize
         return intrinsicContentSize
      }
   }

   private func calculateIntrinsicContentSize() -> NSSize {
      guard let layoutManager = layoutManager, let textContainer = textContainer else {
         return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
      }

      let textHeight = layoutManager.usedRect(for: textContainer).height

      // The layout manager’s `usedRect(for:)` method returns (width of container, height of text).
      // We want to use the width of the text for the intrinsic content size instead of the width
      // of the container, so we need to calculate it ourselves.
      let textWidth = calculateTextWidth()

      let unitSquareSize = self.unitSquareSize

      let intrinsicContentWidth =
         (textWidth + textContainerInset.width * 2) * unitSquareSize.width
      let intrinsicContentHeight =
         (textHeight + textContainerInset.height * 2) * unitSquareSize.height

      return NSSize(width: intrinsicContentWidth.rounded(.up),
                    height: intrinsicContentHeight.rounded(.up))
   }

   /// Calculates the width of the text by unioning all the line fragment used rects.
   private func calculateTextWidth() -> CGFloat {
      guard let layoutManager = layoutManager, let textContainer = textContainer else {
         return NSView.noIntrinsicMetric
      }

      var enclosingRect: NSRect?

      let extraLineFragmentUsedRect = layoutManager.extraLineFragmentUsedRect
      if extraLineFragmentUsedRect.size != NSSize.zero {
         enclosingRect = extraLineFragmentUsedRect
      }

      let glyphRange = layoutManager.glyphRange(for: textContainer)
      layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, lineFragmentUsedRect, _, _, _ in
         if let previousEnclosingRect = enclosingRect {
            enclosingRect = previousEnclosingRect.union(lineFragmentUsedRect)
         } else {
            enclosingRect = lineFragmentUsedRect
         }
      }

      return enclosingRect?.width ?? 0
   }

   // MARK: Responding to Scale Changes

   private var unitSquareSize: NSSize {
      return NSSize(width: AutoLayoutTextView.calculateUnitSquareLength(frameLength: frame.width,
                                                                        boundsLength: bounds.width),
                    height: AutoLayoutTextView.calculateUnitSquareLength(frameLength: frame.height,
                                                                         boundsLength: bounds.height))
   }

   private static func calculateUnitSquareLength(frameLength: CGFloat,
                                                 boundsLength: CGFloat) -> CGFloat {
      let unitSquareLength = frameLength / boundsLength
      guard unitSquareLength != 0 && unitSquareLength.isFinite else {
         return 1
      }

      return unitSquareLength
   }

   open override func scaleUnitSquare(to newUnitSize: NSSize) {
      // The `scaleUnitSquare(to:)` method is poorly named (rdar://45887722). Rather than
      // replacing the current view scale with the new scale, it multiplies the new scale to the
      // current view scale.
      //
      // Since the former behavior is the most intuitive based on the method name, we change the
      // behavior to the former by resetting the scale to 1 before calling the NSView implementation.
      setBoundsSize(frame.size)

      super.scaleUnitSquare(to: newUnitSize)
   }
}
