//
//  PreviewLayoutTest.swift
//  
//
//  Created by Noah Martin on 8/9/24.
//

import Foundation
@_implementationOnly import SnapshotPreviewsCore
import SwiftUI
import XCTest

/// A test class for verifying Xcode previews by forcing a layout pass on each one.
///
/// This class is designed to discover and test SwiftUI previews to ensure they can be laid out without crashing.
/// It provides mechanisms for filtering previews and performs layout tests on different platforms.
open class PreviewLayoutTest: PreviewBaseTest, PreviewFilters {

  /// Returns an optional array of preview names to be included in the snapshot testing. This also supports Regex format.
  ///
  /// Override this method to specify which previews should be included in the test.
  /// - Returns: An optional array of String containing the names of previews to be included.
  open class func snapshotPreviews() -> [String]?  {
    nil
  }

  /// Returns an optional array of preview names to be excluded from the snapshot testing. This also supports Regex format
  ///
  /// Override this method to specify which previews should be excluded from the test.
  /// - Returns: An optional array of String containing the names of previews to be excluded.
  open class func excludedSnapshotPreviews() -> [String]? {
    nil
  }

  /// Returns an optional array of module names to include in preview layout testing.
  ///
  /// Elements should be exact module names from the preview type name, such as "MyModule" in "MyModule.MyView_Previews".
  open class func snapshotPreviewModules() -> [String]? {
    nil
  }

  /// Returns an optional array of module names to exclude from preview layout testing.
  ///
  /// Elements should be exact module names from the preview type name, such as "MyModule" in "MyModule.MyView_Previews".
  open class func excludedSnapshotPreviewModules() -> [String]? {
    nil
  }

  static private var previews: [PreviewType] = []

  /// Discovers all relevant previews based on inclusion and exclusion filters. Subclasses should NOT override this method.
  ///
  /// This method uses `FindPreviews` to locate all previews, applying any specified filters.
  /// - Returns: An array of `DiscoveredPreview` objects representing the found previews.
  @MainActor
  override class func discoverPreviews() -> [DiscoveredPreview] {
    previews = FindPreviews.findPreviews(
      included: Self.snapshotPreviews(),
      excluded: Self.excludedSnapshotPreviews(),
      includedModules: Self.snapshotPreviewModules(),
      excludedModules: Self.excludedSnapshotPreviewModules()
    )
    .filter(SnapshotPreviewInclusionFilter.shouldInclude)
    return previews.map { DiscoveredPreview.from(previewType: $0) }
  }

  /// Tests a specific preview by performing a layout pass. Subclasses should NOT override this method.
  ///
  /// This method creates a hosting controller for the preview and forces a layout pass to verify
  /// that no crashes occur during the process.
  ///
  /// - Parameter preview: A `DiscoveredPreviewAndIndex` object representing the preview to be tested.
  @MainActor
  override func testPreview(_ preview: DiscoveredPreviewAndIndex) {
    let previewType = Self.previews.first { $0.typeName == preview.preview.typeName }
    guard let preview = previewType?.previews[preview.index] else {
      XCTFail("Preview not found")
      return
    }

    #if canImport(UIKit) && !os(watchOS)
    let hostingVC = UIHostingController(rootView: AnyView(preview.view()))
    #if os(visionOS) || os(watchOS)
    hostingVC.view.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
    #else
    hostingVC.view.sizeThatFits(UIScreen.main.bounds.size)
    #endif
    #elseif canImport(AppKit)
    let hostingVC = NSHostingController(rootView: AnyView(preview.view()))
    _ = hostingVC.sizeThatFits(in: NSScreen.main!.frame.size)
    #else
    _ = ImageRenderer(content: AnyView(preview.view())).uiImage
    #endif
  }
}
