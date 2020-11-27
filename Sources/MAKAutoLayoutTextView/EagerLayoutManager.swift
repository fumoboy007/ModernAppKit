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

/// An `NSLayoutManager` subclass that performs layout immediately whenever text changes
/// or whenever the geometry of a text container changes.
///
/// - Attention: The text storage must be an instance of `EagerTextStorage`.
open class EagerLayoutManager: NSLayoutManager, EagerLayoutManaging {
   // MARK: Notifications

   public static let didCompleteLayoutNotification = Notification.Name(rawValue: "mo.darren.ModernAppKit.EagerLayoutManager.didCompleteLayout")

   // MARK: Text Storage

   open override var textStorage: NSTextStorage? {
      didSet {
         if let textStorage = textStorage {
            guard let eagerTextStorage = textStorage as? EagerTextStorage else {
               preconditionFailure("EagerLayoutManager only accepts EagerTextStorage.")
            }
            _textStorage = eagerTextStorage
         }
      }
   }

   private var _textStorage: EagerTextStorage? {
      didSet {
         if _textStorage?.isEditing == false {
            performFullLayout()
         }
      }
   }

   // MARK: Initialization

   public override init() {
      super.init()

      commonInit()
   }

   private func commonInit() {
      // We want to perform layout synchronously instead of asynchronously.
      backgroundLayoutEnabled = false
   }

   // MARK: Serialization/Deserialization

   private enum CoderKey {
      static let textStorage = "mo.darren.ModernAppKit.EagerLayoutManager._textStorage"
   }

   public required init?(coder: NSCoder) {
      self._textStorage = coder.decodeObject(forKey: CoderKey.textStorage) as? EagerTextStorage

      super.init(coder: coder)

      commonInit()
   }

   open override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(self._textStorage, forKey: CoderKey.textStorage)
   }

   // MARK: Performing Layout

   open override func textContainerChangedGeometry(_ container: NSTextContainer) {
      super.textContainerChangedGeometry(container)

      if _textStorage?.isEditing == false {
         performFullLayout()
      }
   }

   open func performFullLayout() {
      guard let textStorage = _textStorage else {
         return
      }
      guard !textStorage.isEditing else {
         return
      }

      ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))

      NotificationCenter.default.post(name: EagerLayoutManager.didCompleteLayoutNotification,
                                      object: self)
   }
}
