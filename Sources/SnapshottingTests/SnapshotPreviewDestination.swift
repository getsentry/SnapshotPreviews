import Foundation

struct SnapshotPreviewDestination {
  static func currentDeviceName(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    environment["SIMULATOR_DEVICE_NAME"] ?? environment["SIMULATOR_MODEL_IDENTIFIER"]
  }
}
