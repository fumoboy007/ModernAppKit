// MIT License
//
// Copyright © 2019 Darren Mo.
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

public class Label: AutoLayoutTextView {
   // MARK: Initialization

   public required init?(coder: NSCoder) {
      super.init(coder: coder)

      commonInit()
   }

   public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
      super.init(frame: frameRect, textContainer: container)

      commonInit()
   }

   private func commonInit() {
      isEditable = false
      drawsBackground = false
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
      setSelectedRange(NSRange(location: 0, length: 0))

      return super.resignFirstResponder()
   }

   // MARK: Ignoring Events When User Interaction Disabled

   public var isUserInteractionEnabled: Bool {
      return isEditable || isSelectable
   }

   public override func hitTest(_ point: NSPoint) -> NSView? {
      if isUserInteractionEnabled {
         return super.hitTest(point)
      } else {
         return nil
      }
   }

   public override var acceptsFirstResponder: Bool {
      return isUserInteractionEnabled && super.acceptsFirstResponder
   }
}
