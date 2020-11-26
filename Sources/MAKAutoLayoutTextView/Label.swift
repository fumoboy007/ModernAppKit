// MIT License
//
// Copyright © 2019-2020 Darren Mo.
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

/// An `AutoLayoutTextView` subclass that acts like a label.
///
/// Specifically, it is non-editable, does not draw a background by default, allows vibrancy, etc.
public class Label: AutoLayoutTextView {
   // MARK: Initialization

   public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
      super.init(frame: frameRect, textContainer: container)

      commonInit()
   }

   private func commonInit() {
      setAccessibilityRole(.staticText)

      super.isEditable = false
      drawsBackground = false
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      private static let prefix = "mo.darren.ModernAppKit.Label"

      static let drawsBackground = "\(prefix).drawsBackground"
   }

   public required init?(coder: NSCoder) {
      super.init(coder: coder)

      commonInit()

      if coder.containsValue(forKey: CoderKey.drawsBackground) {
         drawsBackground = coder.decodeBool(forKey: CoderKey.drawsBackground)
      }
   }

   public override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(drawsBackground, forKey: CoderKey.drawsBackground)
   }

   // MARK: Vibrancy

   public override var allowsVibrancy: Bool {
      return !drawsBackground
   }

   public override var drawsBackground: Bool {
      didSet {
         needsDisplay = true
      }
   }

   // MARK: Simulating NSTextField Behavior

   public override func resignFirstResponder() -> Bool {
      let shouldResign = super.resignFirstResponder()

      if shouldResign {
         setSelectedRange(NSRange(location: 0, length: 0))
      }

      return shouldResign
   }

   // MARK: Ignoring Events

   @available(*, unavailable)
   public override var isEditable: Bool {
      get {
         return super.isEditable
      }

      set {
         super.isEditable = false
      }
   }

   public override func hitTest(_ point: NSPoint) -> NSView? {
      if isSelectable {
         return super.hitTest(point)
      } else {
         return nil
      }
   }

   public override var acceptsFirstResponder: Bool {
      return isSelectable && super.acceptsFirstResponder
   }
}
