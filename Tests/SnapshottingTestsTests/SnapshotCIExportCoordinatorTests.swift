//
//  SnapshotCIExportCoordinatorTests.swift
//  SnapshottingTestsTests
//

import Foundation
import XCTest
@testable import SnapshottingTests
import SnapshotPreviewsCore
import SnapshotSharedModels

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class SnapshotCIExportCoordinatorTests: XCTestCase {

  private var tempDir: URL!

  override func setUp() {
    super.setUp()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SnapshotCIExportTests-\(UUID().uuidString)")
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempDir)
    super.tearDown()
  }

  // MARK: - Factory

  func testCreateFromEnvironmentReturnsNilWhenEnvVarAbsent() {
    let coordinator = SnapshotCIExportCoordinator.createFromEnvironment(environment: [:])
    XCTAssertNil(coordinator)
  }

  func testCreateFromEnvironmentReturnsCoordinatorWhenEnvVarSet() {
    let coordinator = SnapshotCIExportCoordinator.createFromEnvironment(
      environment: [SnapshotCIExportCoordinator.envKey: tempDir.path]
    )
    XCTAssertNotNil(coordinator)
    XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
  }

  // MARK: - Filename Sanitization

  func testSanitizeReplacesUnsafeCharacters() {
    let result = SnapshotCIExportCoordinator.sanitize("My/View:Preview 1")
    let unsafeChars = CharacterSet(charactersIn: "/\\: \"'<>|?*")
    XCTAssertNil(result.rangeOfCharacter(from: unsafeChars))
  }

  func testSanitizeIsDeterministic() {
    let a = SnapshotCIExportCoordinator.sanitize("Some/View:Name")
    let b = SnapshotCIExportCoordinator.sanitize("Some/View:Name")
    XCTAssertEqual(a, b)
  }

  func testSanitizeCollapsesRepeatedUnsafeCharacters() {
    let result = SnapshotCIExportCoordinator.sanitize("A///B   C")
    XCTAssertFalse(result.contains("__"), "Consecutive unsafe chars should collapse to a single underscore")
  }

  func testSanitizePreservesExistingUnderscores() {
    let result = SnapshotCIExportCoordinator.sanitize("A___B")
    XCTAssertEqual(result, "A___B", "Underscores in the input should be preserved as-is")
  }

  func testSanitizeFallsBackForEmptyResult() {
    let result = SnapshotCIExportCoordinator.sanitize("///")
    XCTAssertEqual(result, "snapshot")
  }

  func testSanitizePreservesAlphanumericAndSafeChars() {
    let result = SnapshotCIExportCoordinator.sanitize("Hello_World-2.0")
    XCTAssertEqual(result, "Hello_World-2.0")
  }

  func testRawBaseFileNameUsesDisplayNameWhenUniqueForPreviewProvider() {
    let fileName = makeRawBaseFileName(
      previewDisplayName: "Dark Mode",
      displayNameOccurrenceCount: 1
    )

    XCTAssertEqual(fileName, "Test View_Dark Mode")
  }

  func testRawBaseFileNameFallsBackToIndexForUnnamedPreviewProvider() {
    let fileName = makeRawBaseFileName()

    XCTAssertEqual(fileName, "Test View_0")
  }

  func testRawBaseFileNameUsesDisplayNameOrdinalForDuplicatePreviewProviderDisplayNames() {
    let fileName = makeRawBaseFileName(
      previewDisplayName: "Dark Mode",
      previewIndex: 3,
      displayNameOccurrenceCount: 2,
      duplicateDisplayNameOrdinal: 1
    )

    XCTAssertEqual(fileName, "Test View_Dark Mode_1")
  }

  func testRawBaseFileNameUsesDisplayNameForSinglePreviewMacro() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      previewDisplayName: "Dark Mode",
      line: 42,
      displayNameOccurrenceCount: 1
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_Dark Mode")
  }

  func testRawBaseFileNameFallsBackToLineForAnonymousSinglePreviewMacro() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      line: 42
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_line-42")
  }

  func testRawBaseFileNameUsesDisplayNameForMultiPreviewMacro() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      previewDisplayName: "Dark Mode",
      line: 42,
      displayNameOccurrenceCount: 1
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_Dark Mode")
  }

  func testRawBaseFileNameFallsBackToLineForAnonymousMultiPreviewMacro() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      line: 42
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_line-42")
  }

  func testRawBaseFileNameUsesDisplayNameOrdinalForDuplicateNamedMultiPreviewMacro() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      previewDisplayName: "Dark Mode",
      line: 42,
      displayNameOccurrenceCount: 2,
      duplicateDisplayNameOrdinal: 1
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_Dark Mode_1")
  }

  func testRawBaseFileNameFallsBackToLineWhenDuplicateNamedMultiPreviewMacroOrdinalMissing() {
    let fileName = makeRawBaseFileName(
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      previewDisplayName: "Dark Mode",
      line: 42,
      displayNameOccurrenceCount: 2
    )

    XCTAssertEqual(fileName, "Feature/LoginView.swift_line-42")
  }

  // MARK: - Successful Export

  func testSuccessfulExportWritesPngAndSidecar() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(baseFileName: "TestView_Preview")

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let jsonURL = tempDir.appendingPathComponent("\(context.baseFileName).json")
    let pngURL = tempDir.appendingPathComponent("\(context.baseFileName).png")

    XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))
  }

  // MARK: - Sidecar Content

  func testSidecarUsesPreviewDisplayNameAndTypeDisplayNameForPreviewProviderPresentation() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "Login_Screen_Dark_Mode",
      typeName: "MyModule.LoginScreen_Previews",
      typeDisplayName: "Login Screen",
      previewDisplayName: "Dark Mode"
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)

    XCTAssertEqual(json["display_name"] as? String, "Dark Mode")
    XCTAssertEqual(json["group"] as? String, "Login Screen")
  }

  func testSidecarGroupPrefersFileIdForPreviewMacro() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "Feature_LoginView.swift_line-42",
      typeName: "$s7MyApp11LoginViewV13Preview_42fMf_15LLPreviewRegistryMc",
      typeDisplayName: "Login View",
      fileId: "Feature/LoginView.swift",
      line: 42,
      previewDisplayName: nil
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)

    XCTAssertEqual(json["group"] as? String, "Feature/LoginView.swift")
  }

  func testSidecarDisplayNameFallsBackToAtLineForAnonymousPreviewMacroPresentation() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "Feature_LoginView.swift_line-42",
      fileId: "Feature/LoginView.swift",
      line: 42,
      previewDisplayName: nil
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)

    XCTAssertEqual(json["display_name"] as? String, "At line #42")
  }

  func testSidecarDisplayNameFallsBackToIndexForUnnamedPreviewProviderVariantPresentation() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_0",
      fileId: nil,
      line: nil,
      previewDisplayName: nil,
      previewIndex: 0
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)

    XCTAssertEqual(json["display_name"] as? String, "0")
  }

  func testSidecarGroupFallsBackToTypeNameWhenPreviewProviderDisplayNameUnavailable() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "MyModule.TestView_Previews_0",
      typeName: "MyModule.TestView_Previews",
      typeDisplayName: "",
      fileId: nil,
      line: nil,
      previewDisplayName: nil
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)

    XCTAssertEqual(json["group"] as? String, "MyModule.TestView_Previews")
  }

  func testSidecarNestsContextFieldsUnderContextKey() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_Preview",
      line: 99,
      colorScheme: "dark"
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let nestedContext = try XCTUnwrap(json["context"] as? [String: Any])
    let preview = try XCTUnwrap(nestedContext["preview"] as? [String: Any])

    XCTAssertEqual(preview["container_type_name"] as? String, context.typeName)
    XCTAssertEqual(preview["container_display_name"] as? String, context.typeDisplayName)
    XCTAssertEqual(preview["display_name"] as? String, context.previewDisplayName)
    XCTAssertEqual(preview["index"] as? Int, 0)
    XCTAssertEqual(preview["line"] as? Int, 99)
    XCTAssertEqual(preview["orientation"] as? String, "portrait")
    XCTAssertEqual(preview["preferred_color_scheme"] as? String, "dark")
    XCTAssertEqual(nestedContext["test_name"] as? String, context.testName)

    // Fields that previously sat at the top level no longer do.
    XCTAssertNil(json["tags"])
    XCTAssertNil(json["type_name"])
    XCTAssertNil(json["line"])
    XCTAssertNil(json["color_mode"])
    XCTAssertNil(json["color_scheme"])
    XCTAssertNil(json["orientation"])
  }

  func testSidecarIncludesTagsWhenProvided() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_Tags",
      tags: ["component": "button", "state": "loading"]
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let tags = try XCTUnwrap(json["tags"] as? [String: String])

    XCTAssertEqual(tags["component"], "button")
    XCTAssertEqual(tags["state"], "loading")
  }

  func testSidecarMergesAdditionalContext() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_AdditionalContext",
      additionalContext: [
        "screen": .string("checkout"),
        "attempt": .number(2),
        "is_retry": .bool(true),
        "fixture": .object([
          "name": .string("happy-path"),
          "version": .number(3),
        ]),
      ]
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let nestedContext = try XCTUnwrap(json["context"] as? [String: Any])
    let fixture = try XCTUnwrap(nestedContext["fixture"] as? [String: Any])

    XCTAssertEqual(nestedContext["screen"] as? String, "checkout")
    XCTAssertEqual(nestedContext["attempt"] as? Double, 2)
    XCTAssertEqual(nestedContext["is_retry"] as? Bool, true)
    XCTAssertEqual(fixture["name"] as? String, "happy-path")
    XCTAssertEqual(fixture["version"] as? Double, 3)
  }

  func testAdditionalContextOverridesGeneratedContextKeys() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_ContextOverride",
      additionalContext: [
        "test_name": .string("custom-test-name"),
      ]
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let nestedContext = try XCTUnwrap(json["context"] as? [String: Any])

    XCTAssertEqual(nestedContext["test_name"] as? String, "custom-test-name")
  }

  func testDiffThresholdIsDerivedFromPrecision() {
    XCTAssertEqual(SnapshotCIExportCoordinator.diffThreshold(for: 1.0) ?? .zero, 0.0, accuracy: 0.000_1)
    XCTAssertEqual(SnapshotCIExportCoordinator.diffThreshold(for: 0.8) ?? .zero, 0.2, accuracy: 0.000_1)
    XCTAssertNil(SnapshotCIExportCoordinator.diffThreshold(for: nil))
  }

  func testSidecarIncludesDiffThreshold() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_DiffThreshold",
      diffThreshold: 0.2
    )

    coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let diffThreshold = try XCTUnwrap(json["diff_threshold"] as? Double)

    XCTAssertEqual(diffThreshold, 0.2, accuracy: 0.000_1)
  }

  func testSidecarIncludesDiffThresholdWhenDerivedFromPrecision() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(
      baseFileName: "TestView_BothThresholds",
      diffThreshold: 0.2
    )

    coordinator.enqueueExport(
      result: makeSuccessResult(precision: 0.95),
      context: context)
    coordinator.drain()

    let json = try readJSON(forBaseFileName: context.baseFileName)
    let diffThreshold = try XCTUnwrap(json["diff_threshold"] as? Double)

    XCTAssertEqual(diffThreshold, 0.2, accuracy: 0.000_1)
  }

  // MARK: - Render Failure

  func testRenderFailureProducesNoFiles() {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(baseFileName: "TestView_Preview")

    coordinator.enqueueExport(result: makeFailureResult(), context: context)
    coordinator.drain()

    XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("\(context.baseFileName).png").path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("\(context.baseFileName).json").path))
  }

  // MARK: - Drain Semantics

  func testDrainIsIdempotent() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    let context = makeContext(baseFileName: "TestView_Preview")
    coordinator.enqueueExport(result: makeSuccessResult(), context: context)

    coordinator.drain()
    coordinator.drain()

    XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("\(context.baseFileName).json").path))
  }

  func testDrainOnEmptyQueueDoesNotCrash() {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)
    coordinator.drain()
  }

  // MARK: - Multiple Exports

  func testMultipleExportsProduceIndividualFiles() throws {
    let coordinator = SnapshotCIExportCoordinator(exportDirectoryURL: tempDir)

    let contexts = (0..<5).map { i in
      makeContext(
        baseFileName: "View\(i)_Preview",
        typeName: "Module.View\(i)",
        previewIndex: i
      )
    }

    for context in contexts {
      coordinator.enqueueExport(result: makeSuccessResult(), context: context)
    }
    coordinator.drain()

    for context in contexts {
      XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("\(context.baseFileName).png").path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("\(context.baseFileName).json").path))
    }
  }
}

// MARK: - Test Helpers

extension SnapshotCIExportCoordinatorTests {

  private func readJSON(forBaseFileName baseFileName: String) throws -> [String: Any] {
    let data = try Data(contentsOf: tempDir.appendingPathComponent("\(baseFileName).json"))
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  private func makeRawBaseFileName(
    typeDisplayName: String = "Test View",
    fileId: String? = nil,
    previewDisplayName: String? = nil,
    previewIndex: Int = 0,
    line: Int? = nil,
    displayNameOccurrenceCount: Int = 0,
    duplicateDisplayNameOrdinal: Int? = nil
  ) -> String {
    SnapshotTest.FileNameResolver.rawBaseFileName(
      typeDisplayName: typeDisplayName,
      fileId: fileId,
      previewDisplayName: previewDisplayName,
      previewIndex: previewIndex,
      line: line,
      displayNameOccurrenceCount: displayNameOccurrenceCount,
      duplicateDisplayNameOrdinal: duplicateDisplayNameOrdinal
    )
  }

  private func makeContext(
    baseFileName: String,
    typeName: String = "MyModule.TestView_Previews",
    typeDisplayName: String = "Test View",
    fileId: String? = nil,
    line: Int? = nil,
    previewDisplayName: String? = "Preview",
    previewIndex: Int = 0,
    diffThreshold: Float? = nil,
    colorScheme: String? = nil,
    tags: [String: String] = [:],
    additionalContext: [String: SnapshotMetadataValue] = [:]
  ) -> SnapshotContext {
    SnapshotContext(
      baseFileName: baseFileName,
      testName: "-[MyTests testPreview]",
      typeName: typeName,
      typeDisplayName: typeDisplayName,
      fileId: fileId,
      line: line,
      previewDisplayName: previewDisplayName,
      previewIndex: previewIndex,
      orientation: "portrait",
      simulatorDeviceName: nil,
      simulatorModelIdentifier: nil,
      diffThreshold: diffThreshold,
      accessibilityEnabled: nil,
      colorScheme: colorScheme,
      tags: tags,
      additionalContext: additionalContext
    )
  }

  private func makeTestImage() -> ImageType {
    #if canImport(UIKit)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { ctx in
      UIColor.red.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    #else
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 1,
      pixelsHigh: 1,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )!
    let image = NSImage(size: NSSize(width: 1, height: 1))
    image.addRepresentation(rep)
    return image
    #endif
  }

  private func makeSuccessResult(precision: Float? = nil) -> SnapshotResult {
    SnapshotResult(
      image: .success(makeTestImage()),
      precision: precision,
      accessibilityEnabled: nil,
      colorScheme: nil,
      appStoreSnapshot: nil
    )
  }

  private func makeFailureResult() -> SnapshotResult {
    SnapshotResult(
      image: .failure(NSError(domain: "test", code: 1)),
      precision: nil,
      accessibilityEnabled: nil,
      colorScheme: nil,
      appStoreSnapshot: nil
    )
  }
}
