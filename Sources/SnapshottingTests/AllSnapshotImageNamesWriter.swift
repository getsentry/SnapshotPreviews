import Foundation

final class AllSnapshotImageNamesWriter {
  static let envKey = "SNAPSHOT_PREVIEWS_ALL_IMAGE_NAMES_FILE"

  private let outputURL: URL

  static func createFromEnvironment(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) -> AllSnapshotImageNamesWriter? {
    guard let outputPath = environment[envKey] else {
      return nil
    }

    let trimmed = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      preconditionFailure("\(envKey) is set but empty. Provide a valid file path.")
    }

    let outputURL: URL
    if trimmed.hasPrefix("/") {
      outputURL = URL(fileURLWithPath: trimmed).standardizedFileURL
    } else {
      outputURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .appendingPathComponent(trimmed)
        .standardizedFileURL
    }

    return Self(outputURL: outputURL, fileManager: fileManager)
  }

  init(outputURL: URL, fileManager: FileManager = .default) {
    self.outputURL = outputURL

    do {
      try fileManager.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
    } catch {
      preconditionFailure("Failed to create all snapshot image names directory at \(outputURL.deletingLastPathComponent().path): \(error)")
    }
  }

  func write(imageNames: [String]) {
    let sortedImageNames = Set(imageNames).sorted()
    let contents = sortedImageNames.isEmpty ? "" : "\(sortedImageNames.joined(separator: "\n"))\n"
    guard let data = contents.data(using: .utf8) else {
      preconditionFailure("Failed to encode all snapshot image names file at \(outputURL.path)")
    }

    do {
      try data.write(to: outputURL, options: .atomic)
    } catch {
      preconditionFailure("Failed to write all snapshot image names file at \(outputURL.path): \(error)")
    }
  }
}
