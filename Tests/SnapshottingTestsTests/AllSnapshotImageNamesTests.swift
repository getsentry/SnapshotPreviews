import Foundation
import SwiftUI
@testable import SnapshotPreviewsCore
@testable import SnapshottingTests
import XCTest

@MainActor
final class AllSnapshotImageNamesTests: XCTestCase {
  private var tempDir: URL!

  override func setUp() {
    super.setUp()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("AllSnapshotImageNamesTests-\(UUID().uuidString)")
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempDir)
    super.tearDown()
  }

  func testCurrentDestinationDeviceNamePrefersSimulatorDeviceName() {
    let deviceName = SnapshotPreviewDestination.currentDeviceName(
      environment: [
        "SIMULATOR_DEVICE_NAME": "iPhone 15",
        "SIMULATOR_MODEL_IDENTIFIER": "iPhone16,1",
      ]
    )

    XCTAssertEqual(deviceName, "iPhone 15")
  }

  func testCurrentDestinationDeviceNameFallsBackToSimulatorModelIdentifier() {
    let deviceName = SnapshotPreviewDestination.currentDeviceName(
      environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone16,1"]
    )

    XCTAssertEqual(deviceName, "iPhone16,1")
  }

  func testDiscoveredPreviewDeviceFilterIncludesUndeclaredAndMatchingDevices() {
    let preview = DiscoveredPreview(
      typeName: "Module.TestView_Previews",
      displayName: "Test View",
      devices: ["", "iPhone 15", "iPhone 14"],
      orientations: ["portrait", "portrait", "portrait"],
      numberOfPreviews: 3
    )

    XCTAssertTrue(
      SnapshotPreviewDeviceFilter.shouldInclude(
        discoveredPreview: preview,
        index: 0,
        currentDestinationDeviceName: "iPhone 15"
      )
    )
    XCTAssertTrue(
      SnapshotPreviewDeviceFilter.shouldInclude(
        discoveredPreview: preview,
        index: 1,
        currentDestinationDeviceName: "iPhone 15"
      )
    )
    XCTAssertFalse(
      SnapshotPreviewDeviceFilter.shouldInclude(
        discoveredPreview: preview,
        index: 2,
        currentDestinationDeviceName: "iPhone 15"
      )
    )
  }

  func testWriterReplacesStaleOutputWithSortedDeduplicatedNames() throws {
    let outputURL = tempDir.appendingPathComponent("all-image-names.txt")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try "stale.png\n".write(to: outputURL, atomically: true, encoding: .utf8)

    let writer = try XCTUnwrap(
      AllSnapshotImageNamesWriter.createFromEnvironment(
        environment: [AllSnapshotImageNamesWriter.envKey: outputURL.path]
      )
    )

    writer.write(imageNames: ["Beta.png", "Alpha.png", "Beta.png"])

    XCTAssertEqual(try readAllSnapshotImageNamesFile(at: outputURL), "Alpha.png\nBeta.png\n")
  }

  func testWriterWritesEmptyFileWhenThereAreNoImageNames() throws {
    let outputURL = tempDir.appendingPathComponent("all-image-names.txt")
    let writer = AllSnapshotImageNamesWriter(outputURL: outputURL)

    writer.write(imageNames: [])

    XCTAssertEqual(try readAllSnapshotImageNamesFile(at: outputURL), "")
  }

  func testLogicalImageNamesAreSanitizedPngNamesAndPreserveDuplicateOrdinalsAfterDeviceFiltering() {
    let previewType = PreviewType(
      typeName: "TestModule.AllSnapshotImageNamesTestProvider",
      previewProvider: AllSnapshotImageNamesTestProvider.self
    )
    let resolver = SnapshotTest.FileNameResolver(previews: [previewType])

    let imageNames = SnapshotTest.logicalImageNames(
      previews: [previewType],
      fileNameResolver: resolver,
      environment: ["SIMULATOR_DEVICE_NAME": "iPhone 14"]
    )

    XCTAssertEqual(
      imageNames,
      [
        "All_Snapshot_Image_Names_Test_Provider_Duplicate_1.png",
        "All_Snapshot_Image_Names_Test_Provider_Other.png",
      ]
    )
  }

  func testLogicalImageNamesUsePreviewTypeDeviceWhenDestinationMatches() {
    let previewType = PreviewType(
      typeName: "TestModule.AllSnapshotImageNamesTestProvider",
      previewProvider: AllSnapshotImageNamesTestProvider.self
    )
    let resolver = SnapshotTest.FileNameResolver(previews: [previewType])

    let imageNames = SnapshotTest.logicalImageNames(
      previews: [previewType],
      fileNameResolver: resolver,
      environment: ["SIMULATOR_DEVICE_NAME": "iPhone 15"]
    )

    XCTAssertEqual(
      imageNames,
      [
        "All_Snapshot_Image_Names_Test_Provider_Duplicate_1.png",
        "All_Snapshot_Image_Names_Test_Provider_Duplicate_2.png",
        "All_Snapshot_Image_Names_Test_Provider_Other.png",
      ]
    )
  }

  private func readAllSnapshotImageNamesFile(at url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }
}

private struct AllSnapshotImageNamesTestProvider: PreviewProvider {
  static var previews: some View {
    Group {
      Text("One")
        .previewDisplayName("Duplicate")
      Text("Two")
        .previewDisplayName("Duplicate")
        .previewDevice("iPhone 15")
      Text("Three")
        .previewDisplayName("Other")
    }
  }
}
