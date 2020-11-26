// swift-tools-version:5.3

import PackageDescription

let package = Package(
   name: "ModernAppKit",
   platforms: [
      .macOS(.v10_13),
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
   dependencies: [
      .package(name: "SnapshotTesting", url: "https://github.com/fumoboy007/swift-snapshot-testing.git", .branch("nsview")),
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
      .testTarget(
         name: "MAKAutoLayoutTextViewTests",
         dependencies: [
            "MAKAutoLayoutTextView",
            "MAKTestUtilities",
            "SnapshotTesting",
         ],
         exclude: [
            "__Snapshots__",
         ]
      ),

      .target(
         name: "MAKLayerView"
      ),
      .testTarget(
         name: "MAKLayerViewTests",
         dependencies: [
            "MAKLayerView",
            "MAKTestUtilities",
            "SnapshotTesting",
         ],
         exclude: [
            "__Snapshots__",
         ]
      ),

      .target(
         name: "MAKShadowView"
      ),
      .testTarget(
         name: "MAKShadowViewTests",
         dependencies: [
            "MAKLayerView",
            "MAKShadowView",
            "MAKTestUtilities",
            "SnapshotTesting",
         ],
         exclude: [
            "__Snapshots__",
         ]
      ),

      .target(
         name: "MAKTestUtilities"
      ),
   ]
)
