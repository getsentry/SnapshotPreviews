//
//  SnapshotCIExportCoordinator.swift
//  SnapshottingTests
//
//  Manages CI export of snapshot PNGs and JSON sidecar metadata
//  directly to the filesystem when SNAPSHOTS_EXPORT_DIR is set.
//

import Foundation
import XCTest
import SnapshotSharedModels
@_implementationOnly import SnapshotPreviewsCore

// MARK: - Snapshot Context

struct SnapshotContext: Sendable {
  let imageFileName: String

  var sidecarFileName: String {
    "\(String(imageFileName.dropLast(".png".count))).json"
  }
  
  let testName: String
  let typeName: String
  let typeDisplayName: String
  let fileId: String?
  let line: Int?
  let previewDisplayName: String?
  let previewIndex: Int
  let orientation: String
  let simulatorDeviceName: String?
  let simulatorModelIdentifier: String?
  let diffThreshold: Float?
  let accessibilityEnabled: Bool?
  let colorScheme: String?
  let tags: [String: String]
  let additionalContext: [String: SnapshotMetadataValue]
  let groupOverride: SnapshotGroup?
}

// MARK: - Sidecar Model

private enum SnapshotSidecarContextKey {
  /// The XCTest test name that produced this snapshot.
  static let testName = "test_name"
  /// Whether the snapshot was rendered with accessibility metadata enabled.
  static let accessibilityEnabled = "accessibility_enabled"
  /// Simulator metadata for the device that rendered this snapshot.
  static let simulator = "simulator"
  /// Preview metadata for the SwiftUI preview that produced this snapshot.
  static let preview = "preview"

  enum Simulator {
    /// Human-readable simulator device name, if available.
    static let deviceName = "device_name"
    /// Simulator model identifier, if available.
    static let modelIdentifier = "model_identifier"
  }

  enum Preview {
    /// The preview's zero-based index within its container.
    static let index = "index"
    /// The author-declared `.previewDisplayName(...)` value, if set.
    static let displayName = "display_name"
    /// Fully-qualified type name of the container that declared this preview
    /// (the `PreviewProvider` struct, or the compiler-synthesized `PreviewRegistry`
    /// conformance for a `#Preview` macro).
    static let containerTypeName = "container_type_name"
    /// Human-readable label derived from the container's type name or file name.
    /// Not author-declared — there's no SwiftUI API to set it.
    static let containerDisplayName = "container_display_name"
    /// The author-declared `.preferredColorScheme(_:)` value, if set. `"light"` or `"dark"`.
    static let preferredColorScheme = "preferred_color_scheme"
    /// The author-declared preview interface orientation (e.g. `"portrait"`, `"landscapeLeft"`).
    /// Defaults to `"portrait"` when the author doesn't declare one.
    static let orientation = "orientation"
    /// The source line that declared the preview, if available.
    static let line = "line"
  }
}

private struct SnapshotSidecar: Sendable, Encodable {
  let displayName: String
  let group: String
  let diffThreshold: Float?
  let tags: [String: String]?
  let context: [String: SnapshotMetadataValue]

  init(
    context: SnapshotContext,
    displayName: String,
    group: String
  ) {
    self.displayName = displayName
    self.group = group
    self.diffThreshold = context.diffThreshold
    self.tags = context.tags.isEmpty ? nil : context.tags

    var generatedContext: [String: SnapshotMetadataValue] = [
      SnapshotSidecarContextKey.testName: .string(context.testName),
      SnapshotSidecarContextKey.accessibilityEnabled: .bool(context.accessibilityEnabled ?? false),
      SnapshotSidecarContextKey.preview: .object(Self.previewContext(from: context)),
    ]

    if let simulatorContext = Self.simulatorContext(from: context) {
      generatedContext[SnapshotSidecarContextKey.simulator] = .object(simulatorContext)
    }

    generatedContext.merge(context.additionalContext, uniquingKeysWith: { _, userValue in userValue })
    self.context = generatedContext
  }

  private static func simulatorContext(from context: SnapshotContext) -> [String: SnapshotMetadataValue]? {
    var simulator: [String: SnapshotMetadataValue] = [:]

    if let deviceName = context.simulatorDeviceName {
      simulator[SnapshotSidecarContextKey.Simulator.deviceName] = .string(deviceName)
    }

    if let modelIdentifier = context.simulatorModelIdentifier {
      simulator[SnapshotSidecarContextKey.Simulator.modelIdentifier] = .string(modelIdentifier)
    }

    return simulator.isEmpty ? nil : simulator
  }

  private static func previewContext(from context: SnapshotContext) -> [String: SnapshotMetadataValue] {
    var preview: [String: SnapshotMetadataValue] = [
      SnapshotSidecarContextKey.Preview.index: .number(Double(context.previewIndex)),
      SnapshotSidecarContextKey.Preview.containerTypeName: .string(context.typeName),
      SnapshotSidecarContextKey.Preview.containerDisplayName: .string(context.typeDisplayName),
    ]

    if let previewDisplayName = context.previewDisplayName {
      preview[SnapshotSidecarContextKey.Preview.displayName] = .string(previewDisplayName)
    }

    if let colorScheme = context.colorScheme {
      preview[SnapshotSidecarContextKey.Preview.preferredColorScheme] = .string(colorScheme)
    }

    if !context.orientation.isEmpty {
      preview[SnapshotSidecarContextKey.Preview.orientation] = .string(context.orientation)
    }

    if let line = context.line {
      preview[SnapshotSidecarContextKey.Preview.line] = .number(Double(line))
    }

    return preview
  }
}

// MARK: - Coordinator

final class SnapshotCIExportCoordinator: NSObject, XCTestObservation {

  static let envKey = "SNAPSHOTS_EXPORT_DIR"

  static func diffThreshold(for precision: Float?) -> Float? {
    precision.map { 1 - $0 }
  }

  private let exportDirectoryURL: URL
  private let writeQueue: OperationQueue
  private let fileManager: FileManager
  private let stateLock = NSLock()
  private var hasDrained = false

  // MARK: - Factory

  static func createFromEnvironment(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> SnapshotCIExportCoordinator? {
    guard let exportDir = environment[envKey] else {
      return nil
    }

    let trimmed = exportDir.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      preconditionFailure(
        "\(envKey) is set but empty. Provide a valid directory path."
      )
    }

    let url: URL
    if trimmed.hasPrefix("/") {
      url = URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
    } else {
      url = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
      )
      .appendingPathComponent(trimmed, isDirectory: true)
      .standardizedFileURL
    }

    let coordinator = Self(exportDirectoryURL: url)
    XCTestObservationCenter.shared.addTestObserver(coordinator)
    return coordinator
  }

  // MARK: - Init

  init(
    exportDirectoryURL: URL,
    fileManager: FileManager = .default,
    writeQueue: OperationQueue = .defaultQueue
  ) {
    self.exportDirectoryURL = exportDirectoryURL
    self.fileManager = fileManager
    self.writeQueue = writeQueue

    super.init()

    do {
      try self.fileManager.createDirectory(
        at: exportDirectoryURL,
        withIntermediateDirectories: true
      )
    } catch {
      preconditionFailure(
        "Failed to create snapshot export directory at \(exportDirectoryURL.path): \(error)"
      )
    }
  }

  // MARK: - Export

  static func canonicalGroup(
    fileId: String?,
    typeDisplayName: String,
    typeName: String
  ) -> String {
    if let fileId, !fileId.isEmpty {
      return fileId
    }

    if !typeDisplayName.isEmpty {
      return typeDisplayName
    }

    return typeName
  }

  static func canonicalGroup(for previewType: SnapshotPreviewsCore.PreviewType) -> String {
    canonicalGroup(
      fileId: previewType.fileID,
      typeDisplayName: previewType.displayName,
      typeName: previewType.typeName
    )
  }

  /// Resolves the top-level sidecar `group`, preferring the author-declared override
  /// and falling back to the generated canonical group.
  static func resolvedGroup(for context: SnapshotContext) -> String {
    lazy var fallback = canonicalGroup(
      fileId: context.fileId,
      typeDisplayName: context.typeDisplayName,
      typeName: context.typeName
    )

    switch context.groupOverride {
    case .none, .default:
      return fallback
    case .custom(let group):
      let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? fallback : trimmed
    case .module:
      return moduleName(from: context.typeName) ?? fallback
    }
  }

  private static func moduleName(from typeName: String) -> String? {
    guard let dotIndex = typeName.firstIndex(of: "."), dotIndex != typeName.startIndex else {
      return nil
    }
    return String(typeName[..<dotIndex])
  }

  private static func canonicalDisplayName(for context: SnapshotContext) -> String {
    if let previewDisplayName = context.previewDisplayName, !previewDisplayName.isEmpty {
      return previewDisplayName
    }

    if context.fileId != nil, let line = context.line {
      return "At line #\(line)"
    }

    return String(context.previewIndex)
  }

  /// Enqueues a snapshot export (PNG + JSON sidecar) to the export directory.
  ///
  /// PNG encoding and file writes are dispatched to a concurrent background queue
  /// so the calling test can proceed to the next preview immediately.
  func enqueueExport(
    result: SnapshotResult,
    context: SnapshotContext
  ) {
    let pngFileName = context.imageFileName
    let jsonFileName = context.sidecarFileName

    let displayName = Self.canonicalDisplayName(for: context)
    let group = Self.resolvedGroup(for: context)
    let exportDir = exportDirectoryURL
    
    guard case .success(let image) = result.image else { return }
    
    writeQueue.addOperation {
      let pngURL = exportDir.appendingPathComponent(pngFileName)
      guard let pngData = image.emg.pngData() else {
        NSLog("[SnapshotCIExport] Failed to encode PNG for %@", pngFileName)
        return
      }
      do {
        try pngData.write(to: pngURL, options: .atomic)
      } catch {
        NSLog("[SnapshotCIExport] Failed to write PNG %@: %@", pngFileName, "\(error)")
        return
      }

      let sidecar = SnapshotSidecar(
        context: context,
        displayName: displayName,
        group: group
      )

      let jsonURL = exportDir.appendingPathComponent(jsonFileName)
      do {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        try data.write(to: jsonURL, options: .atomic)
      } catch {
        NSLog("[SnapshotCIExport] Failed to write sidecar %@: %@", jsonFileName, "\(error)")
      }
    }
  }

  // MARK: - Drain

  /// Waits for all queued PNG and sidecar writes to complete.
  ///
  /// Called automatically via `testBundleDidFinish`. Safe to call multiple times —
  /// only the first call performs the drain.
  func drain() {
    stateLock.lock()
    guard !hasDrained else {
      stateLock.unlock()
      return
    }
    hasDrained = true
    stateLock.unlock()

    writeQueue.waitUntilAllOperationsAreFinished()
  }

  // MARK: - XCTestObservation

  func testBundleDidFinish(_ testBundle: Bundle) {
    drain()
  }
}

private extension OperationQueue {
  static var defaultQueue: OperationQueue {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 20
    queue.qualityOfService = .userInitiated
    return queue
  }
}
