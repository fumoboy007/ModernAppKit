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

@testable import MAKShadowView

import Cocoa
import MAKLayerView
import SnapshotTesting
import XCTest

final class ShadowViewTests: XCTestCase {
   // MARK: - Properties

   private var shadowView: ShadowView!

   // MARK: - Setup/Teardown

   override func setUp() {
      super.setUp()

      let contentView = LayerView()
      contentView.backgroundColor = .green

      shadowView = ShadowView()
      shadowView.contentView = contentView
      shadowView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
         shadowView.widthAnchor.constraint(equalToConstant: 40),
         shadowView.heightAnchor.constraint(equalToConstant: 40)
      ])
   }

   override func tearDown() {
      // Release the shadow view so that the cached shadow image is also released.
      shadowView = nil

      super.tearDown()
   }

   // MARK: - Tests

   func testDefaultShadowPropertyValues() {
      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testCustomizableShadowProperties() {
      shadowView.shadowBlurRadius = 10
      shadowView.shadowOffset = .zero
      shadowView.shadowColor = .red

      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testTopLeftShadow() {
      shadowView.shadowOffset = NSSize(width: -20, height: 20)
      shadowView.shadowColor = .red

      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testTopRightShadow() {
      shadowView.shadowOffset = NSSize(width: 20, height: 20)
      shadowView.shadowColor = .red

      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testBottomLeftShadow() {
      shadowView.shadowOffset = NSSize(width: -20, height: -20)
      shadowView.shadowColor = .red

      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testBottomRightShadow() {
      shadowView.shadowOffset = NSSize(width: 20, height: -20)
      shadowView.shadowColor = .red

      assertSnapshot(matching: shadowView,
                     as: .image)
   }

   func testShadowImageCache() {
      let shadowImageProperties = ShadowImageProperties(shadowBlurRadius: 100,
                                                        shadowColor: .cyan)
      XCTAssertEqual(ShadowCache.shared.retainCountForShadowImage(with: shadowImageProperties), 0)

      do {
         let shadowView1 = ShadowView()
         shadowView1.shadowBlurRadius = shadowImageProperties.shadowBlurRadius
         shadowView1.shadowColor = shadowImageProperties.shadowColor
         XCTAssertEqual(ShadowCache.shared.retainCountForShadowImage(with: shadowImageProperties), 1)

         do {
            let shadowView1 = ShadowView()
            shadowView1.shadowBlurRadius = shadowImageProperties.shadowBlurRadius
            shadowView1.shadowColor = shadowImageProperties.shadowColor
            XCTAssertEqual(ShadowCache.shared.retainCountForShadowImage(with: shadowImageProperties), 2)
         }

         XCTAssertEqual(ShadowCache.shared.retainCountForShadowImage(with: shadowImageProperties), 1)
      }

      XCTAssertEqual(ShadowCache.shared.retainCountForShadowImage(with: shadowImageProperties), 0)
   }

   func testRenderedShadowImageCache() {
      let shadowImageProperties = ShadowImageProperties(shadowBlurRadius: shadowView.shadowBlurRadius,
                                                        shadowColor: shadowView.shadowColor)
      XCTAssertEqual(ShadowCache.shared.renderCountForShadowImage(with: shadowImageProperties), 0)

      triggerRendering(of: shadowView,
                       backingScaleFactor: 1)
      XCTAssertEqual(ShadowCache.shared.renderCountForShadowImage(with: shadowImageProperties), 1)

      triggerRendering(of: shadowView,
                       backingScaleFactor: 1)
      XCTAssertEqual(ShadowCache.shared.renderCountForShadowImage(with: shadowImageProperties), 1)

      triggerRendering(of: shadowView,
                       backingScaleFactor: 2)
      XCTAssertEqual(ShadowCache.shared.renderCountForShadowImage(with: shadowImageProperties), 2)

      triggerRendering(of: shadowView,
                       backingScaleFactor: 1)
      XCTAssertEqual(ShadowCache.shared.renderCountForShadowImage(with: shadowImageProperties), 2)
   }

   // MARK: - Private

   private func triggerRendering(of view: NSView,
                                 backingScaleFactor: CGFloat) {
      let snapshotCompletionExpectation = expectation(description: "Expected the snapshotting to complete.")

      Snapshotting
         .image(windowForDrawing: .newWindow(backingScaleFactor: backingScaleFactor))
         .snapshot(view)
         .run { image in
            snapshotCompletionExpectation.fulfill()
         }

      wait(for: [snapshotCompletionExpectation], timeout: 1)
   }
}
