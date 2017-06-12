// MIT License
//
// Copyright © 2016-2017 Darren Mo.
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

/// An `NSTextView` subclass that implements `intrinsicContentSize` so that the text view
/// can participate in layout outside of a scroll view.
open class AutoLayoutTextView: NSTextView {
   // MARK: Text Components

   private var _textStorage: EagerTextStorage?
   open override var textStorage: NSTextStorage? {
      return _textStorage
   }

   private var _layoutManager: EagerLayoutManager?
   open override var layoutManager: NSLayoutManager? {
      return _layoutManager
   }

   /// Text container for the text view.
   ///
   /// The text view will use the text storage and layout manager associated with the specified
   /// text container. The text storage and layout manager must be instances of
   /// `EagerTextStorage` and `EagerLayoutManager`, respectively.
   open override var textContainer: NSTextContainer? {
      willSet {
         if let layoutManager = _layoutManager {
            NotificationCenter.default.removeObserver(self,
                                                      name: EagerLayoutManager.didCompleteLayout,
                                                      object: layoutManager)
         }
      }

      didSet {
         if let textContainer = textContainer {
            if let layoutManager = textContainer.layoutManager {
               precondition(layoutManager is EagerLayoutManager, "AutoLayoutTextView requires the layout manager to be an instance of EagerLayoutManager.")
               self._layoutManager = layoutManager as? EagerLayoutManager

               if let textStorage = layoutManager.textStorage {
                  precondition(textStorage is EagerTextStorage, "AutoLayoutTextView requires the text storage to be an instance of EagerTextStorage.")
                  self._textStorage = textStorage as? EagerTextStorage
               }
            }
         }

         if let layoutManager = _layoutManager {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(didCompleteLayout(_:)),
                                                   name: EagerLayoutManager.didCompleteLayout,
                                                   object: layoutManager)
         }
      }
   }

   // MARK: Initialization

   private static let textStorageCoderKey = "mo.darren.ModernAppKit.AutoLayoutTextView._textStorage"
   private static let layoutManagerCoderKey = "mo.darren.ModernAppKit.AutoLayoutTextView._layoutManager"

   public override convenience init(frame frameRect: NSRect) {
      // NSTextView defaults
      let textContainer = NSTextContainer(size: NSSize(width: 0, height: 10000000))
      textContainer.widthTracksTextView = true
      textContainer.lineFragmentPadding = 0  // not an NSTextView default, but this value makes more sense

      let layoutManager = EagerLayoutManager()
      layoutManager.addTextContainer(textContainer)

      let textStorage = EagerTextStorage()
      textStorage.addLayoutManager(layoutManager)

      self.init(frame: frameRect, textContainer: textContainer)
   }

   public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
      if let textContainer = container {
         if let layoutManager = textContainer.layoutManager {
            precondition(layoutManager is EagerLayoutManager, "AutoLayoutTextView requires the layout manager to be an instance of EagerLayoutManager.")
            self._layoutManager = layoutManager as? EagerLayoutManager

            if let textStorage = layoutManager.textStorage {
               precondition(textStorage is EagerTextStorage, "AutoLayoutTextView requires the text storage to be an instance of EagerTextStorage.")
               self._textStorage = textStorage as? EagerTextStorage
            }
         }
      }

      super.init(frame: frameRect, textContainer: container)

      if let layoutManager = _layoutManager {
         NotificationCenter.default.addObserver(self,
                                                selector: #selector(didCompleteLayout(_:)),
                                                name: EagerLayoutManager.didCompleteLayout,
                                                object: layoutManager)
      }
   }

   public required init?(coder: NSCoder) {
      self._textStorage = coder.decodeObject(forKey: AutoLayoutTextView.textStorageCoderKey) as! EagerTextStorage?
      self._layoutManager = coder.decodeObject(forKey: AutoLayoutTextView.layoutManagerCoderKey) as! EagerLayoutManager?

      super.init(coder: coder)

      if let layoutManager = _layoutManager {
         NotificationCenter.default.addObserver(self,
                                                selector: #selector(didCompleteLayout(_:)),
                                                name: EagerLayoutManager.didCompleteLayout,
                                                object: layoutManager)
      }
   }

   open override func encode(with aCoder: NSCoder) {
      super.encode(with: aCoder)

      aCoder.encode(_textStorage, forKey: AutoLayoutTextView.textStorageCoderKey)
      aCoder.encode(_layoutManager, forKey: AutoLayoutTextView.layoutManagerCoderKey)
   }

   deinit {
      if let layoutManager = _layoutManager {
         // Because NSTextView does not support weak references, NotificationCenter will not
         // automatically remove the observer for us.
         NotificationCenter.default.removeObserver(self,
                                                   name: EagerLayoutManager.didCompleteLayout,
                                                   object: layoutManager)
      }
   }

   // MARK: Intrinsic Content Size

   /// Called when the layout manager completes layout.
   ///
   /// The default implementation of this method invalidates the intrinsic content size.
   @objc
   open func didCompleteLayout(_ notification: Notification) {
      invalidateIntrinsicContentSize()
   }

   open override var intrinsicContentSize: NSSize {
      guard let layoutManager = layoutManager, let textContainer = textContainer else {
         return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
      }

      var textSize = layoutManager.usedRect(for: textContainer).size
      textSize.width = (textSize.width + textContainerInset.width * 2).rounded(.up)
      textSize.height = (textSize.height + textContainerInset.height * 2).rounded(.up)

      return textSize
   }

   // MARK: -

   /// A concrete `NSTextStorage` subclass that tells its `EagerLayoutManager` objects to
   /// perform layout after every edit.
   open class EagerTextStorage: NSTextStorage {
      // MARK: Notifications

      public static let willChange = Notification.Name(rawValue: "mo.darren.ModernAppKit.AutoLayoutTextView.EagerTextStorage.willChange")

      // MARK: Backing Store

      /// We use NSTextStorage as the backing store for two reasons.
      ///
      /// (1) NSTextStorage might use some special, performant backing store. We want to use that.
      ///
      /// (2) The `string` property getter is called a lot by the typesetter object. The NSString
      ///     object returned by `backingStore.string` needs to be bridged to String. This involves
      ///     a CFStringCreateCopy. If the backing store is an NSConcreteMutableAttributedString,
      ///     which uses __NSCFString, then the copy is O(n). If the backing store is an
      ///     NSConcreteTextStorage, which uses NSConcreteNotifyingMutableAttributedString, which
      ///     uses NSBigMutableString, then the copy is O(1).
      private static let backingStoreType: NSMutableAttributedString.Type = NSTextStorage.self

      private let backingStore: NSMutableAttributedString

      // MARK: Nested Editing State

      private var editingCount = 0
      var isEditing: Bool {
         return editingCount > 0
      }

      // MARK: Initialization

      private static let backingStoreCoderKey = "mo.darren.ModernAppKit.AutoLayoutTextView.EagerTextStorage.backingStore"

      public override init() {
         self.backingStore = EagerTextStorage.backingStoreType.init()

         super.init()
      }

      public required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
         self.backingStore = EagerTextStorage.backingStoreType.init()

         super.init(pasteboardPropertyList: propertyList, ofType: type)
      }

      public required init?(coder aDecoder: NSCoder) {
         self.backingStore = aDecoder.decodeObject(forKey: EagerTextStorage.backingStoreCoderKey) as! NSMutableAttributedString

         super.init(coder: aDecoder)
      }

      open override func encode(with aCoder: NSCoder) {
         super.encode(with: aCoder)

         aCoder.encode(backingStore, forKey: EagerTextStorage.backingStoreCoderKey)
      }

      // MARK: Custom Change Notifications

      open override func beginEditing() {
         editingCount += 1

         super.beginEditing()
         backingStore.beginEditing()
      }

      open override func edited(_ editedMask: NSTextStorageEditActions,
                                range editedRange: NSRange,
                                changeInLength delta: Int) {
         super.edited(editedMask,
                      range: editedRange,
                      changeInLength: delta)

         if !isEditing {
            performFullLayout()
         }
      }

      open override func endEditing() {
         backingStore.endEditing()
         super.endEditing()

         editingCount -= 1

         if !isEditing {
            performFullLayout()
         }
      }

      private func performFullLayout() {
         for layoutManager in layoutManagers {
            if let eagerLayoutManager = layoutManager as? EagerLayoutManager {
               eagerLayoutManager.performFullLayout()
            }
         }
      }

      // MARK: NSMutableAttributedString Primitives

      open override var string: String {
         return backingStore.string
      }

      open override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedStringKey : Any] {
         return backingStore.attributes(at: location, effectiveRange: range)
      }

      open override func replaceCharacters(in range: NSRange, with str: String) {
         NotificationCenter.default.post(name: EagerTextStorage.willChange,
                                         object: self)

         backingStore.replaceCharacters(in: range, with: str)
         edited(.editedCharacters,
                range: range,
                changeInLength: (str as NSString).length - range.length)
      }

      open override func setAttributes(_ attrs: [NSAttributedStringKey : Any]?, range: NSRange) {
         NotificationCenter.default.post(name: EagerTextStorage.willChange,
                                         object: self)

         backingStore.setAttributes(attrs, range: range)
         edited(.editedAttributes,
                range: range,
                changeInLength: 0)
      }
   }

   // MARK: -

   /// An `NSLayoutManager` subclass that performs layout immediately whenever text changes
   /// or whenever the geometry of a text container changes. `EagerLayoutManager` posts a
   /// `.didCompleteLayout` notification when it completes layout. The text storage must be
   /// an instance of `EagerTextStorage`.
   open class EagerLayoutManager: NSLayoutManager {
      // MARK: Notifications

      public static let didCompleteLayout = Notification.Name(rawValue: "mo.darren.ModernAppKit.AutoLayoutTextView.EagerLayoutManager.didCompleteLayout")

      // MARK: Text Storage

      open override var textStorage: NSTextStorage? {
         didSet {
            if let textStorage = textStorage {
               precondition(textStorage is EagerTextStorage, "EagerLayoutManager only accepts EagerTextStorage.")
               _textStorage = textStorage as? EagerTextStorage
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

      private static let textStorageCoderKey = "mo.darren.ModernAppKit.AutoLayoutTextView.EagerLayoutManager._textStorage"

      public override init() {
         super.init()

         // Since we are performing layout eagerly, we don’t need background layout
         self.backgroundLayoutEnabled = false
      }

      public required init?(coder: NSCoder) {
         self._textStorage = coder.decodeObject(forKey: EagerLayoutManager.textStorageCoderKey) as? EagerTextStorage

         super.init(coder: coder)
      }

      open override func encode(with aCoder: NSCoder) {
         super.encode(with: aCoder)

         aCoder.encode(self._textStorage, forKey: EagerLayoutManager.textStorageCoderKey)
      }

      // MARK: Performing Layout

      open override func textContainerChangedGeometry(_ container: NSTextContainer) {
         super.textContainerChangedGeometry(container)

         if _textStorage?.isEditing == false {
            performFullLayout()
         }
      }

      func performFullLayout() {
         guard let textStorage = _textStorage else {
            return
         }
         guard !textStorage.isEditing else {
            return
         }

         ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))

         NotificationCenter.default.post(name: EagerLayoutManager.didCompleteLayout,
                                         object: self)
      }
   }
}
