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

@testable import MAKLayerView

import Cocoa
import MAKTestUtilities
import SnapshotTesting
import XCTest

final class LayerViewTests: XCTestCase {
   // MARK: - Properties

   private var layerView: LayerView!

   // MARK: - Setup/Teardown

   override func setUp() {
      super.setUp()

      layerView = LayerView(frame: NSRect(x: 0,
                                          y: 0,
                                          width: 20,
                                          height: 20))
   }

   // MARK: - Tests

   func testDefaultLayerPropertyValues() {
      assertSnapshot(matching: layerView,
                     as: .image)
   }

   func testCustomizableLayerProperties() {
      layerView.backgroundColor = .red
      layerView.borderWidth = .points(3)
      layerView.borderColor = .green
      layerView.cornerRadius = 5

      assertSnapshot(matching: layerView,
                     as: .image)
   }

   func testBorderWidthInPoints() {
      layerView.borderWidth = .points(8)

      assertSnapshot(matching: layerView,
                     as: .image(windowForDrawing: .newWindow(backingScaleFactor: 1)),
                     named: "1x")
      // The border should have the same relative thickness as the 1x snapshot.
      assertSnapshot(matching: layerView,
                     as: .image(windowForDrawing: .newWindow(backingScaleFactor: 2)),
                     named: "2x")
   }

   func testBorderWidthInPixels() {
      layerView.borderWidth = .pixels(8)

      assertSnapshot(matching: layerView,
                     as: .image(windowForDrawing: .newWindow(backingScaleFactor: 1)),
                     named: "1x")
      // The border should look thinner compared to the 1x snapshot.
      assertSnapshot(matching: layerView,
                     as: .image(windowForDrawing: .newWindow(backingScaleFactor: 2)),
                     named: "2x")
   }

   func testSerialization() throws {
      layerView.backgroundColor = .red
      layerView.borderWidth = .points(3)
      layerView.borderColor = .green
      layerView.cornerRadius = 5
      assertSnapshot(matching: layerView,
                     as: .image,
                     named: "original")

      let deserializedLayerView = try LayerView.make(bySerializingAndDeserializing: layerView)

      XCTAssertEqual(deserializedLayerView.backgroundColor, layerView.backgroundColor)
      XCTAssertEqual(deserializedLayerView.borderWidth, layerView.borderWidth)
      XCTAssertEqual(deserializedLayerView.borderColor, layerView.borderColor)
      XCTAssertEqual(deserializedLayerView.cornerRadius, layerView.cornerRadius)

      // Should be the same as the above snapshot of the original view.
      assertSnapshot(matching: deserializedLayerView,
                     as: .image,
                     named: "deserialized")
   }

   func testDeserializationWithSerializedNSView() throws {
      assertSnapshot(matching: layerView,
                     as: .image,
                     named: "default")

      let deserializedLayerView = try LayerView.make(bySerializingAndDeserializing: NSView())

      XCTAssertEqual(deserializedLayerView.backgroundColor, layerView.backgroundColor)
      XCTAssertEqual(deserializedLayerView.borderWidth, layerView.borderWidth)
      XCTAssertEqual(deserializedLayerView.borderColor, layerView.borderColor)
      XCTAssertEqual(deserializedLayerView.cornerRadius, layerView.cornerRadius)

      // Should be the same as the above snapshot of the layer view with default property values.
      assertSnapshot(matching: deserializedLayerView,
                     as: .image(size: layerView.frame.size),
                     named: "deserialized")
   }

   func testNormalPropertyAnimations() {
      let fromBackgroundColor = NSColor.red
      let fromBorderColor = NSColor.green
      let fromCornerRadius: CGFloat = 0

      let toBackgroundColor = NSColor.green
      let toBorderColor = NSColor.red
      let toCornerRadius: CGFloat = 100

      layerView.backgroundColor = fromBackgroundColor
      layerView.borderColor = fromBorderColor
      layerView.cornerRadius = fromCornerRadius

      runAnimationsUntilHalfDuration(duration: 2) { layerView in
         layerView.backgroundColor = toBackgroundColor
         layerView.borderColor = toBorderColor
         layerView.cornerRadius = toCornerRadius
      }

      XCTAssertNotEqual(layerView.backgroundColor, fromBackgroundColor)
      XCTAssertNotEqual(layerView.backgroundColor, toBackgroundColor)
      XCTAssertNotEqual(layerView.borderColor, fromBorderColor)
      XCTAssertNotEqual(layerView.borderColor, toBorderColor)
      XCTAssertNotEqual(layerView.cornerRadius, fromCornerRadius)
      XCTAssertNotEqual(layerView.cornerRadius, toCornerRadius)
   }

   func testAnimatableBorderWidthInPoints() {
      let fromValue: CGFloat = 300
      let toValue: CGFloat = 400

      layerView.borderWidth = .points(fromValue)

      runAnimationsUntilHalfDuration(duration: 2) { layerView in
         layerView.animatableBorderWidthInPoints = toValue
      }

      switch layerView.borderWidth {
      case .points(let borderWidthInPoints):
         XCTAssertGreaterThan(borderWidthInPoints, fromValue)
         XCTAssertLessThan(borderWidthInPoints, toValue)

      default:
         XCTFail()
      }
   }

   func testAnimatableBorderWidthInPixels() {
      let fromValue: CGFloat = 300
      let toValue: CGFloat = 400

      layerView.borderWidth = .pixels(fromValue)

      runAnimationsUntilHalfDuration(duration: 2) { layerView in
         layerView.animatableBorderWidthInPixels = toValue
      }

      switch layerView.borderWidth {
      case .pixels(let borderWidthInPixels):
         XCTAssertGreaterThan(borderWidthInPixels, fromValue)
         XCTAssertLessThan(borderWidthInPixels, toValue)

      default:
         XCTFail()
      }
   }

   // MARK: - Private

   private func runAnimationsUntilHalfDuration(duration: TimeInterval,
                                               changes: (LayerView) -> Void) {
      NSAnimationContext.runAnimationGroup { context in
         context.duration = duration
         changes(layerView.animator())
      }

      RunLoop.current.run(until: Date(timeIntervalSinceNow: duration / 2))
   }
}
