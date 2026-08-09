@_implementationOnly import SnapshotPreviewsCore
import SnapshotSharedModels

enum SnapshotPreviewInclusionFilter {
  static func shouldInclude(preview: PreviewType) -> Bool {
    guard #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *) else { return true }
    guard preview.previews.count == 1 else { return true }
    return !preview.previews[0].modifiers.contains { ($0 as? SnapshotInclusionMode) == .excluded }
  }
}
