// MIT License
//
// Copyright © 2020 Darren Mo.
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

@testable import MAKAutoLayoutTextView
@testable import MAKEagerTextStorage

import Cocoa
import SnapshotTesting
import XCTest

final class AutoLayoutTextViewTests: XCTestCase {
   // MARK: - Private Properties

   private static let attributedTextFake: NSAttributedString = {
      let text = """
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      """
      return NSAttributedString(string: text)
   }()

   private static let smallWidth: CGFloat = 20
   private static let largeWidth: CGFloat = 10000
   private static let smallHeight: CGFloat = 20

   // MARK: - Tests

   func testEagerLayoutForTextChange() {
      let textView = AutoLayoutTextView()
      let layoutManager = textView.layoutManager!
      let textStorage = textView.textStorage!

      expectation(forNotification: EagerTextStorage.willChangeNotification,
                  object: textStorage,
                  handler: nil)
      expectation(forNotification: EagerTextStorage.didChangeNotification,
                  object: textStorage,
                  handler: nil)
      expectation(forNotification: EagerLayoutManager.didCompleteLayoutNotification,
                  object: layoutManager,
                  handler: nil)

      textStorage.append(AutoLayoutTextViewTests.attributedTextFake)

      waitForExpectations(timeout: 0, handler: nil)
   }

   func testBatchedEdits() {
      let textView = AutoLayoutTextView()
      let layoutManager = textView.layoutManager!
      let textStorage = textView.textStorage!

      expectation(forNotification: EagerTextStorage.willChangeNotification,
                  object: textStorage,
                  handler: nil)
      expectation(forNotification: EagerTextStorage.didChangeNotification,
                  object: textStorage,
                  handler: nil)
      expectation(forNotification: EagerLayoutManager.didCompleteLayoutNotification,
                  object: layoutManager,
                  handler: nil)

      textStorage.beginEditing()
      textStorage.append(AutoLayoutTextViewTests.attributedTextFake)
      textStorage.append(AutoLayoutTextViewTests.attributedTextFake)
      textStorage.endEditing()

      waitForExpectations(timeout: 0, handler: nil)
   }

   func testEagerLayoutForContainerSizeChange() {
      let textView = AutoLayoutTextView()
      let textContainer = textView.textContainer!
      let layoutManager = textView.layoutManager!

      expectation(forNotification: EagerLayoutManager.didCompleteLayoutNotification,
                  object: layoutManager,
                  handler: nil)

      textContainer.size.width += 1

      waitForExpectations(timeout: 0, handler: nil)
   }

   func testTracksWidthAndNotHeightByDefault() {
      let textView = AutoLayoutTextView(frame: NSRect(x: 0,
                                                      y: 0,
                                                      width: AutoLayoutTextViewTests.smallWidth,
                                                      height: AutoLayoutTextViewTests.smallHeight))

      textView.textStorage!.append(AutoLayoutTextViewTests.attributedTextFake)

      let intrinsicContentSize = textView.intrinsicContentSize
      XCTAssertLessThanOrEqual(intrinsicContentSize.width, AutoLayoutTextViewTests.smallWidth)
      XCTAssertGreaterThanOrEqual(intrinsicContentSize.height, AutoLayoutTextViewTests.smallHeight)

      // Text should not be horizontally clipped.
      assertSnapshot(matching: textView,
                     as: .image)
   }

   func testNoWidthTracking() {
      let textView = AutoLayoutTextView(frame: NSRect(x: 0,
                                                      y: 0,
                                                      width: AutoLayoutTextViewTests.smallWidth,
                                                      height: AutoLayoutTextViewTests.smallHeight))
      let textContainer = textView.textContainer!
      textContainer.widthTracksTextView = false
      textContainer.size.width = AutoLayoutTextViewTests.largeWidth

      textView.textStorage!.append(AutoLayoutTextViewTests.attributedTextFake)

      let intrinsicContentSize = textView.intrinsicContentSize
      XCTAssertGreaterThanOrEqual(intrinsicContentSize.width, AutoLayoutTextViewTests.smallWidth)

      // Text should be horizontally clipped.
      assertSnapshot(matching: textView,
                     as: .image)
   }

   func testScaleUnitSquare() {
      let textView = AutoLayoutTextView(frame: NSRect(x: 0,
                                                      y: 0,
                                                      width: AutoLayoutTextViewTests.smallWidth,
                                                      height: AutoLayoutTextViewTests.smallHeight))
      textView.textStorage!.append(AutoLayoutTextViewTests.attributedTextFake)

      let unscaledIntrinsicContentSize = textView.intrinsicContentSize
      assertSnapshot(matching: textView,
                     as: .image(size: NSSize(width: unscaledIntrinsicContentSize.width,
                                             height: textView.frame.height)),
                     named: "unscaled")

      let scaleFactor: CGFloat = 2
      textView.scaleUnitSquare(to: NSSize(width: scaleFactor, height: scaleFactor))

      let scaledIntrinsicContentSize = textView.intrinsicContentSize
      // The multiple may not be exactly equal to the scale factor due to rounding, so we need to apply rounding too.
      XCTAssertEqual((scaledIntrinsicContentSize.width / unscaledIntrinsicContentSize.width).rounded(.up), scaleFactor)
      XCTAssertEqual((scaledIntrinsicContentSize.height / unscaledIntrinsicContentSize.height).rounded(.up), scaleFactor)

      // Should have the same visible text as the above unscaled snapshot but scaled by `scaleFactor`.
      assertSnapshot(matching: textView,
                     as: .image(size: NSSize(width: scaledIntrinsicContentSize.width,
                                             height: (textView.frame.height * scaleFactor).rounded(.up))),
                     named: "scaled")
   }
}
