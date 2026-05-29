// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapshotPreviews",
    platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v9)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
          name: "PreviewGallery",
          type: .static, // Replace this to build dynamic
          targets: ["PreviewGallery"]),
        // Test library to import in your XCTest target.
        // This is the only library that depends on XCTest.framework
        .library(
          name: "SnapshottingTests",
          type: .static, // Replace this to build dynamic
          targets: ["SnapshottingTests"]),
        // Link the main app to this target to use custom snapshot settings
        // This lib does not get inserted when running tests to avoid
        // duplicate symbols.
        .library(
          name: "SnapshotPreferences",
          targets: ["SnapshotPreferences"]),
        // Core functionality for snapshotting exported from the internal package
        .library(
          name: "SnapshotPreviewsCore",
          targets: ["SnapshotPreviewsCore"]),
        // Dynamic library that your main app will have inserted to generate previews
        .library(
          name: "Snapshotting",
          type: .dynamic,
          targets: ["Snapshotting"]),
    ],
    dependencies: [
      .package(url: "https://github.com/swhitty/FlyingFox.git", exact: "0.16.0"),
      .package(url: "https://github.com/EmergeTools/SimpleDebugger.git", exact: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Target that provides the XCTest
      .target(name: "SnapshottingTestsObjc", dependencies: [.product(name: "SimpleDebugger", package: "SimpleDebugger", condition: .when(platforms: [.iOS, .macOS, .macCatalyst]))]),
        .target(name: "SnapshottingTests", dependencies: ["SnapshotPreviewsCore", "SnapshottingTestsObjc", "SnapshotSharedModels"]),
        .target(name: "SnapshotSharedModels"),
        // Core functionality
        .target(name: "SnapshotPreviewsCore", dependencies: ["PreviewsSupport", "SnapshotSharedModels"]),
        .target(name: "SnapshotPreferences", dependencies: ["SnapshotSharedModels"]),
        // Inserted dylib
        .target(name: "Snapshotting", dependencies: ["SnapshottingSwift"]),
        // Swift code in the inserted dylib
        .target(name: "SnapshottingSwift", dependencies: ["SnapshotPreviewsCore", .product(name: "FlyingFox", package: "FlyingFox")]),
        .target(name: "PreviewGallery", dependencies: ["SnapshotPreviewsCore", "SnapshotPreferences"]),
        .binaryTarget(
          name: "PreviewsSupport",
          path: "PreviewsSupport/PreviewsSupport.xcframework"),
        .testTarget(
            name: "SnapshotPreviewsTests",
            dependencies: ["SnapshotPreviewsCore"]),
        .testTarget(
            name: "SnapshotPreferencesTests",
            dependencies: ["SnapshotPreferences", "SnapshotSharedModels"]),
        .testTarget(
            name: "SnapshottingTestsTests",
            dependencies: ["SnapshottingTests", "SnapshotPreviewsCore", "SnapshotSharedModels"]),
    ],
    cxxLanguageStandard: .cxx11
)
