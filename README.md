# ModernAppKit
An assortment of enhancements to AppKit to support modern app development. Addresses deficiencies in Auto Layout support, layer-backed views, and shadows.

Written in Swift 3. Tested on macOS 10.11 and macOS 10.12. MIT license.

## AutoLayoutTextView
An `NSTextView` subclass that implements `intrinsicContentSize` so that the text view can participate in layout outside of a scroll view.

## LayerView
A layer-backed view with additional APIs for setting background color, border width, border color, and corner radius. Use if you do not need to do custom drawing. Supports animations.

## ShadowView
A container view that draws a rectangular shadow underneath its content view in a performant manner.