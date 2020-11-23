// swift-tools-version:5.3

import PackageDescription

let package = Package(
   name: "ModernAppKit",
   platforms: [
      .macOS(.v10_11),
   ],
   products: [
      .library(
         name: "MAKAutoLayoutTextView",
         targets: [
            "MAKAutoLayoutTextView",
         ]
      ),
      .library(
         name: "MAKLayerView",
         targets: [
            "MAKLayerView",
         ]
      ),
      .library(
         name: "MAKShadowView",
         targets: [
            "MAKShadowView",
         ]
      ),
   ],
   targets: [
      .target(
         name: "MAKAutoLayoutTextView",
         dependencies: [
            "MAKEagerTextStorage",
         ]
      ),
      .target(
         name: "MAKEagerTextStorage"
      ),
      .target(
         name: "MAKLayerView"
      ),
      .target(
         name: "MAKShadowView"
      ),
   ]
)
