// MIT License
//
// Copyright © 2017-2020 Darren Mo.
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

#import "MAKEagerTextStorage.h"

#import "MAKEagerLayoutManaging.h"

NS_ASSUME_NONNULL_BEGIN

// MARK: Notifications

NSNotificationName const MAKEagerTextStorageWillChangeNotification = @"mo.darren.ModernAppKit.EagerTextStorage.willChange";
NSNotificationName const MAKEagerTextStorageDidChangeNotification = @"mo.darren.ModernAppKit.EagerTextStorage.didChange";

// MARK: Backing Store

/// We use NSTextStorage as the backing store for two reasons.
///
/// (1) NSTextStorage might use some special, performant backing store. We want to use that.
///
/// (2) The `string` property getter could be called a lot from Swift code. The NSString object
///     returned by `_backingStore.string` needs to be bridged to String. This involves
///     a CFStringCreateCopy. If the backing store is an NSConcreteMutableAttributedString,
///     which uses __NSCFString, then the copy is O(n). If the backing store is an
///     NSConcreteTextStorage, which uses NSConcreteNotifyingMutableAttributedString, which
///     uses NSBigMutableString, then the copy is O(1).
#define MAKEagerTextStorageBackingStoreClass ([NSTextStorage class])

// MARK: -

@implementation MAKEagerTextStorage {
   NSMutableAttributedString *_backingStore;

   NSInteger _editingCount;
}

// MARK: Nested Editing State

- (BOOL)isEditing {
   return _editingCount > 0;
}

// MARK: Initialization

- (instancetype)init {
   self = [super init];

   if (self) {
      _backingStore = [[MAKEagerTextStorageBackingStoreClass alloc] init];
   }

   return self;
}

- (instancetype)initWithString:(NSString *)str {
   self = [super init];

   if (self) {
      _backingStore = [[MAKEagerTextStorageBackingStoreClass alloc] initWithString:str];
   }

   return self;
}

- (instancetype)initWithString:(NSString *)str
                    attributes:(nullable NSDictionary<NSAttributedStringKey,id> *)attrs {
   self = [super init];

   if (self) {
      _backingStore = [[MAKEagerTextStorageBackingStoreClass alloc] initWithString:str
                                                                        attributes:attrs];
   }

   return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr {
   self = [super init];

   if (self) {
      _backingStore = [[MAKEagerTextStorageBackingStoreClass alloc] initWithAttributedString:attrStr];
   }

   return self;
}

// MARK: Custom Change Notifications

- (void)beginEditing {
   if (!self.editing) {
      [self willBeginEditing];
   }

   _editingCount += 1;

   [super beginEditing];
   [_backingStore beginEditing];
}

- (void)edited:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
   [super edited:editedMask range:editedRange changeInLength:delta];

   if (!self.editing) {
      [self didEndEditing];
   }
}

- (void)endEditing {
   [_backingStore endEditing];
   [super endEditing];

   _editingCount -= 1;

   if (!self.editing) {
      [self didEndEditing];
   }
}

- (void)willBeginEditing {
   [[NSNotificationCenter defaultCenter] postNotificationName:MAKEagerTextStorageWillChangeNotification
                                                       object:self];
}

- (void)didEndEditing {
   [self performFullLayout];

   [[NSNotificationCenter defaultCenter] postNotificationName:MAKEagerTextStorageDidChangeNotification
                                                       object:self];
}

- (void)performFullLayout {
   for (NSLayoutManager *layoutManager in self.layoutManagers) {
      if ([layoutManager conformsToProtocol:@protocol(MAKEagerLayoutManaging)]) {
         id<MAKEagerLayoutManaging> eagerLayoutManager = (id<MAKEagerLayoutManaging>)layoutManager;
         [eagerLayoutManager performFullLayout];
      }
   }
}

// MARK: NSMutableAttributedString Primitives

- (NSString *)string {
   return _backingStore.string;
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(nullable NSRangePointer)range {
   return [_backingStore attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
   if (!self.editing) {
      [self willBeginEditing];
   }

   [_backingStore replaceCharactersInRange:range withString:str];
   [self edited:NSTextStorageEditedCharacters range:range changeInLength:(str.length - range.length)];
}

- (void)setAttributes:(nullable NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
   if (!self.editing) {
      [self willBeginEditing];
   }

   [_backingStore setAttributes:attrs range:range];
   [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

@end

NS_ASSUME_NONNULL_END
