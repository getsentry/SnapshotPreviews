//
//  SnapshotTest.swift
//
//
//  Created by Noah Martin on 8/9/24.
//

import Foundation
@_implementationOnly import SnapshotPreviewsCore
import enum SwiftUI.ColorScheme
import protocol SwiftUI.ViewModifier
import XCTest

extension ColorScheme {
  var stringValue: String? {
    switch self {
    case .light:
      return "light"
    case .dark:
      return "dark"
    @unknown default:
      return nil
    }
  }
}

/// A test class for generating snapshots of Xcode previews.
///
/// This class is designed to discover SwiftUI previews, render them, and generate snapshot images for testing purposes.
/// It provides mechanisms for filtering previews and supports different rendering strategies based on the platform.
open class SnapshotTest: PreviewBaseTest, PreviewFilters {

  private struct FileNameKey: Hashable {
    let typeName: String
    let previewIndex: Int
  }

  struct FileNameResolver {
    private typealias PreviewGroup = String
    private typealias PreviewDisplayName = String

    private struct DuplicateKey: Hashable {
      let group: PreviewGroup
      let displayName: PreviewDisplayName
    }

    private struct PreviewMeta {
      let previewType: SnapshotPreviewsCore.PreviewType
      let group: PreviewGroup
      let prefix: String
    }

    private let rawBaseFileNameByKey: [FileNameKey: String]

    init(previews: [SnapshotPreviewsCore.PreviewType]) {
      let metas = previews.map { previewType in
        PreviewMeta(
          previewType: previewType,
          group: SnapshotCIExportCoordinator.canonicalGroup(for: previewType),
          prefix: Self.fileNamePrefix(typeDisplayName: previewType.displayName, fileId: previewType.fileID)
        )
      }

      // First pass: count previews sharing each (group, displayName) to detect
      // duplicates that need disambiguation.
      var displayNameCountByGroup: [PreviewGroup: [PreviewDisplayName: Int]] = [:]
      for meta in metas {
        for preview in meta.previewType.previews {
          guard let displayName = preview.displayName, !displayName.isEmpty else { continue }
          displayNameCountByGroup[meta.group, default: [:]][displayName, default: 0] += 1
        }
      }

      // Second pass: assign a 1-based ordinal to each duplicate occurrence and
      // build the raw base file name for every preview.
      var nextOrdinalByKey: [DuplicateKey: Int] = [:]
      var rawBaseFileNameByKey: [FileNameKey: String] = [:]

      for meta in metas {
        let displayNameCounts = displayNameCountByGroup[meta.group] ?? [:]

        for (previewIndex, preview) in meta.previewType.previews.enumerated() {
          let occurrenceCount = preview.displayName.flatMap { displayNameCounts[$0] } ?? 0

          var ordinal: Int?
          if let displayName = preview.displayName, occurrenceCount > 1 {
            let ordinalKey = DuplicateKey(group: meta.group, displayName: displayName)
            let next = nextOrdinalByKey[ordinalKey, default: 1]
            nextOrdinalByKey[ordinalKey] = next + 1
            ordinal = next
          }

          let component = Self.fileNameComponent(
            previewDisplayName: preview.displayName,
            previewIndex: previewIndex,
            fileId: meta.previewType.fileID,
            line: meta.previewType.line,
            displayNameOccurrenceCount: occurrenceCount,
            duplicateDisplayNameOrdinal: ordinal
          )

          let key = FileNameKey(typeName: meta.previewType.typeName, previewIndex: previewIndex)
          rawBaseFileNameByKey[key] = "\(meta.prefix)_\(component)"
        }
      }

      self.rawBaseFileNameByKey = rawBaseFileNameByKey
    }

    func rawBaseFileName(typeName: String, previewIndex: Int) -> String? {
      rawBaseFileNameByKey[FileNameKey(typeName: typeName, previewIndex: previewIndex)]
    }

    static func rawBaseFileName(
      typeDisplayName: String,
      fileId: String?,
      previewDisplayName: String?,
      previewIndex: Int,
      line: Int?,
      displayNameOccurrenceCount: Int,
      duplicateDisplayNameOrdinal: Int?
    ) -> String {
      let prefix = fileNamePrefix(typeDisplayName: typeDisplayName, fileId: fileId)
      let component = fileNameComponent(
        previewDisplayName: previewDisplayName,
        previewIndex: previewIndex,
        fileId: fileId,
        line: line,
        displayNameOccurrenceCount: displayNameOccurrenceCount,
        duplicateDisplayNameOrdinal: duplicateDisplayNameOrdinal
      )
      return "\(prefix)_\(component)"
    }

    private static func fileNamePrefix(typeDisplayName: String, fileId: String?) -> String {
      if let fileId, !fileId.isEmpty {
        return fileId
      }
      return typeDisplayName
    }

    private static func fileNameComponent(
      previewDisplayName: String?,
      previewIndex: Int,
      fileId: String?,
      line: Int?,
      displayNameOccurrenceCount: Int,
      duplicateDisplayNameOrdinal: Int?
    ) -> String {
      if let previewDisplayName, !previewDisplayName.isEmpty {
        if displayNameOccurrenceCount <= 1 {
          return previewDisplayName
        }
        if let duplicateDisplayNameOrdinal {
          return "\(previewDisplayName)_\(duplicateDisplayNameOrdinal)"
        }
      }

      if fileId != nil, let line {
        return "line-\(line)"
      }

      return String(previewIndex)
    }
  }

  /// Returns an optional array of preview names to be included in the snapshot testing. This also supports Regex format.
  ///
  /// Override this method to specify which previews should be included in the snapshot test.
  /// - Returns: An optional array of String containing the names of previews to be included.
  open class func snapshotPreviews() -> [String]? {
    nil
  }
  
  /// Returns an optional array of preview names to be excluded from the snapshot testing. This also supports Regex format.
  ///
  /// Override this method to specify which previews should be excluded from the snapshot test.
  /// - Returns: An optional array of String containing the names of previews to be excluded.
  open class func excludedSnapshotPreviews() -> [String]? {
    nil
  }

  /// Returns an optional array of module names to include in snapshot testing.
  ///
  /// Elements should be exact module names from the preview type name, such as "MyModule" in "MyModule.MyView_Previews".
  open class func snapshotPreviewModules() -> [String]? {
    nil
  }

  /// Returns an optional array of module names to exclude from snapshot testing.
  ///
  /// Elements should be exact module names from the preview type name, such as "MyModule" in "MyModule.MyView_Previews".
  open class func excludedSnapshotPreviewModules() -> [String]? {
    nil
  }

  #if canImport(UIKit) && !os(watchOS) && !os(visionOS) && !os(tvOS)
  open class func setupA11y() -> ((UIViewController, UIWindow, PreviewLayout) -> UIView)? {
    return nil
  }
  #endif

  /// Determines the appropriate rendering strategy based on the current platform and OS version.
  ///
  /// This method selects between UIKit, AppKit, and SwiftUI rendering strategies depending on the available frameworks and OS version.
  /// - Returns: A `RenderingStrategy` object suitable for the current environment.
  #if canImport(UIKit) && !os(watchOS) && !os(visionOS) && !os(tvOS)
  private static func makeRenderingStrategy(a11y: ((UIViewController, UIWindow, PreviewLayout) -> UIView)?) -> RenderingStrategy {
    return UIKitRenderingStrategy(a11yWrapper: a11y)
  }
  #else
  private static func makeRenderingStrategy() -> RenderingStrategy {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
      AppKitRenderingStrategy()
    #else
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
      SwiftUIRenderingStrategy()
    } else {
      preconditionFailure("Cannot snapshot on this device/os")
    }
    #endif
  }
    #endif
  private static var renderingStrategy: RenderingStrategy? = nil
  @MainActor private static var ciExportCoordinator: SnapshotCIExportCoordinator?
  @MainActor private static var allSnapshotImageNamesWriter: AllSnapshotImageNamesWriter?

  static private var previews: [SnapshotPreviewsCore.PreviewType] = []
  static private var fileNameResolver = FileNameResolver(previews: [])

  @MainActor
  override class func discoverPreviews() -> [DiscoveredPreview] {
    allSnapshotImageNamesWriter = AllSnapshotImageNamesWriter.createFromEnvironment()
    if allSnapshotImageNamesWriter == nil {
      ciExportCoordinator = SnapshotCIExportCoordinator.createFromEnvironment()
    } else {
      ciExportCoordinator = nil
    }

    previews = FindPreviews.findPreviews(
      included: Self.snapshotPreviews(),
      excluded: Self.excludedSnapshotPreviews(),
      includedModules: Self.snapshotPreviewModules(),
      excludedModules: Self.excludedSnapshotPreviewModules()
    )
    fileNameResolver = FileNameResolver(previews: previews)

    if let allSnapshotImageNamesWriter {
      allSnapshotImageNamesWriter.write(
        imageNames: logicalImageNames(previews: previews, fileNameResolver: fileNameResolver)
      )
      return []
    }

    return previews.map { DiscoveredPreview.from(previewType: $0) }
  }

  static func logicalImageNames(
    previews: [SnapshotPreviewsCore.PreviewType],
    fileNameResolver: FileNameResolver,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String] {
    let currentDeviceName = SnapshotPreviewDestination.currentDeviceName(environment: environment)
    var imageNames: [String] = []

    for previewType in previews {
      for previewIndex in previewType.previews.indices {
        let requestedDeviceName = previewType.previews[previewIndex].device?.rawValue
        guard SnapshotPreviewDeviceFilter.shouldInclude(
          requestedDeviceName: requestedDeviceName,
          currentDestinationDeviceName: currentDeviceName
        ) else {
          continue
        }

        guard let rawBaseFileName = fileNameResolver.rawBaseFileName(
          typeName: previewType.typeName,
          previewIndex: previewIndex
        ) else {
          continue
        }

        imageNames.append(FileNameUtils.imageFileName(from: rawBaseFileName))
      }
    }

    return imageNames
  }

  /// Tests a specific preview by rendering it and generating a snapshot. Subclasses should NOT override this method.
  ///
  /// This method renders the specified preview using the appropriate rendering strategy,
  /// creates a snapshot image, and attaches it to the test results.
  ///
  /// - Parameter discoveredPreview: A `DiscoveredPreviewAndIndex` object representing the preview to be tested.
  @MainActor
  override func testPreview(_ discoveredPreview: DiscoveredPreviewAndIndex) {
    guard let previewType = Self.previews.first(where: { $0.typeName == discoveredPreview.preview.typeName }) else {
      XCTFail("Preview type not found")
      return
    }

    let preview = previewType.previews[discoveredPreview.index]

    // Lazily create the rendering strategy
    if Self.renderingStrategy == nil {
      #if canImport(UIKit) && !os(watchOS) && !os(visionOS) && !os(tvOS)
      let strategy = Self.makeRenderingStrategy(a11y: Self.setupA11y())
      #else
      let strategy = Self.makeRenderingStrategy()
      #endif
      Self.renderingStrategy = strategy
    }

    let renderInput = Preview(contents: .init(previewType: previewType, preview: preview))
    guard let output = render(renderInput) else {
      // skipped
      return
    }

    let result = output.contents.result

    guard let rawBaseFileName = Self.fileNameResolver.rawBaseFileName(
      typeName: previewType.typeName,
      previewIndex: discoveredPreview.index
    ) else {
      XCTFail("Preview file name not found")
      return
    }

    let imageFileName = FileNameUtils.imageFileName(from: rawBaseFileName)
    if let coordinator = Self.ciExportCoordinator {
      let colorSchemeValue = result.colorScheme.flatMap { $0.stringValue }
      let context = SnapshotContext(
        imageFileName: imageFileName,
        testName: name,
        typeName: previewType.typeName,
        typeDisplayName: previewType.displayName,
        fileId: previewType.fileID,
        line: previewType.line,
        previewDisplayName: preview.displayName,
        previewIndex: discoveredPreview.index,
        orientation: preview.orientation.id,
        simulatorDeviceName: ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"],
        simulatorModelIdentifier: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
        diffThreshold: SnapshotCIExportCoordinator.diffThreshold(for: result.precision),
        accessibilityEnabled: result.accessibilityEnabled,
        colorScheme: colorSchemeValue,
        tags: result.tags,
        additionalContext: result.additionalContext,
        groupOverride: result.groupOverride,
        canvasTheme: result.canvasTheme)
      coordinator.enqueueExport(result: result, context: context)
    } else {
      do {
        let attachment = try XCTAttachment(image: result.image.get())
        attachment.name = String(imageFileName.dropLast(".png".count))
        attachment.lifetime = .keepAlways
        add(attachment)
      } catch {
        XCTFail("Error \(error)")
      }
    }
  }

  /// The preview to render in ``SnapshotTest/render(_:)``.
  public struct Preview {
    final class Contents {
      // We need this and RenderOutput.Contents because the SnapshotPreviewsCore import
      // is @_implementationOnly, so clients don't know these types' layouts. Changing to
      // struct compiles, but triggers a compiler crash at external use sites.

      let previewType: SnapshotPreviewsCore.PreviewType
      let preview: SnapshotPreviewsCore.Preview

      init(previewType: SnapshotPreviewsCore.PreviewType, preview: SnapshotPreviewsCore.Preview) {
        self.previewType = previewType
        self.preview = preview
      }
    }

    var contents: Contents

    public var typeName: String {
      contents.previewType.typeName
    }

    /// Returns a new `Preview` with the given `ViewModifier` applied.
    public func modifier(_ modifier: some ViewModifier) -> Self {
      var copy = self
      // copy Contents to maintain value semantics
      copy.contents = Contents(
        previewType: contents.previewType,
        preview: contents.preview.modifier(modifier)
      )
      return copy
    }
  }

  /// An opaque type that represents the result of ``SnapshotTest/render(_:)``.
  public struct RenderOutput {
    final class Contents {
      let result: SnapshotResult

      init(result: SnapshotResult) {
        self.result = result
      }
    }

    var contents: Contents
  }

  /// Renders the given preview.
  /// 
  /// You may override this to perform custom setup or teardown around the rendering process.
  /// If you do so, either return the result of `super.render(_:)`, or return `nil` to skip.
  @MainActor
  open func render(_ preview: Preview) -> RenderOutput? {
    guard let strategy = Self.renderingStrategy else {
      XCTFail("Missing rendering strategy")
      return nil
    }

    var result: SnapshotResult? = nil
    let expectation = XCTestExpectation()
    strategy.render(preview: preview.contents.preview) { snapshotResult in
      result = snapshotResult
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 10)

    guard let result else {
      XCTFail("Did not render")
      return nil
    }

    return RenderOutput(contents: .init(result: result))
  }
}
