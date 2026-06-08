// swift-tools-version: 5.7

import Foundation
import PackageDescription

let product = ProcessInfo.processInfo.environment["SNAPSHOT_PREVIEWS_XCFRAMEWORK_PRODUCT"] ?? ""

func selectedTargets() -> [Target] {
  switch product {
  case "SnapshotSharedModels":
    return [
      .target(name: "SnapshotSharedModels"),
    ]
  case "SnapshotPreviewsCore":
    return [
      .target(name: "SnapshotPreviewsCore", dependencies: ["PreviewsSupport", "SnapshotSharedModels"]),
      .binaryTarget(name: "PreviewsSupport", path: "XCFrameworks/PreviewsSupport.xcframework"),
      .binaryTarget(name: "SnapshotSharedModels", path: "XCFrameworks/SnapshotSharedModels.xcframework"),
    ]
  case "SnapshotPreferences":
    return [
      .target(name: "SnapshotPreferences", dependencies: ["SnapshotSharedModels"]),
      .binaryTarget(name: "SnapshotSharedModels", path: "XCFrameworks/SnapshotSharedModels.xcframework"),
    ]
  case "PreviewGallery":
    return [
      .target(name: "PreviewGallery", dependencies: ["PreviewsSupport", "SnapshotSharedModels", "SnapshotPreviewsCore", "SnapshotPreferences"]),
      .binaryTarget(name: "PreviewsSupport", path: "XCFrameworks/PreviewsSupport.xcframework"),
      .binaryTarget(name: "SnapshotSharedModels", path: "XCFrameworks/SnapshotSharedModels.xcframework"),
      .binaryTarget(name: "SnapshotPreviewsCore", path: "XCFrameworks/SnapshotPreviewsCore.xcframework"),
      .binaryTarget(name: "SnapshotPreferences", path: "XCFrameworks/SnapshotPreferences.xcframework"),
    ]
  case "SnapshottingTests":
    return [
      .target(name: "SnapshottingTestsObjc", dependencies: [.product(name: "SimpleDebugger", package: "SimpleDebugger", condition: .when(platforms: [.iOS, .macOS, .macCatalyst]))]),
      .target(name: "SnapshottingTests", dependencies: ["PreviewsSupport", "SnapshotSharedModels", "SnapshotPreviewsCore", "SnapshottingTestsObjc"]),
      .binaryTarget(name: "PreviewsSupport", path: "XCFrameworks/PreviewsSupport.xcframework"),
      .binaryTarget(name: "SnapshotSharedModels", path: "XCFrameworks/SnapshotSharedModels.xcframework"),
      .binaryTarget(name: "SnapshotPreviewsCore", path: "XCFrameworks/SnapshotPreviewsCore.xcframework"),
    ]
  case "Snapshotting":
    return [
      .target(name: "Snapshotting", dependencies: ["SnapshottingSwift"]),
      .target(name: "SnapshottingSwift", dependencies: ["PreviewsSupport", "SnapshotSharedModels", "SnapshotPreviewsCore", .product(name: "FlyingFox", package: "FlyingFox")]),
      .binaryTarget(name: "PreviewsSupport", path: "XCFrameworks/PreviewsSupport.xcframework"),
      .binaryTarget(name: "SnapshotSharedModels", path: "XCFrameworks/SnapshotSharedModels.xcframework"),
      .binaryTarget(name: "SnapshotPreviewsCore", path: "XCFrameworks/SnapshotPreviewsCore.xcframework"),
    ]
  default:
    fatalError("Set SNAPSHOT_PREVIEWS_XCFRAMEWORK_PRODUCT to the framework being built")
  }
}

let package = Package(
  name: product,
  platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v9)],
  products: [
    .library(name: product, type: .dynamic, targets: [product]),
  ],
  dependencies: [
    .package(url: "https://github.com/swhitty/FlyingFox.git", exact: "0.16.0"),
    .package(url: "https://github.com/EmergeTools/SimpleDebugger.git", exact: "1.0.0"),
  ],
  targets: selectedTargets(),
  cxxLanguageStandard: .cxx11
)
