//
//  SnapshotMetadataPreference.swift
//

import Foundation
import SwiftUI
import SnapshotSharedModels

struct SnapshotTagsPreferenceKey: PreferenceKey {
  static var defaultValue: [String: String] = [:]

  static func reduce(value: inout [String: String], nextValue: () -> [String: String]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct SnapshotAdditionalContextPreferenceKey: PreferenceKey {
  static var defaultValue: [String: SnapshotMetadataValue] = [:]

  static func reduce(
    value: inout [String: SnapshotMetadataValue],
    nextValue: () -> [String: SnapshotMetadataValue]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

extension View {
  /// Adds tags to the exported snapshot sidecar.
  ///
  /// Repeated modifiers merge their dictionaries. If the same key is set more than once,
  /// the later modifier value is used.
  public func snapshotTags(_ tags: [String: String]) -> some View {
    preference(key: SnapshotTagsPreferenceKey.self, value: tags)
  }

  /// Adds custom metadata to the exported snapshot sidecar `context` object.
  ///
  /// Supported values are strings, numbers, booleans, and nested dictionaries containing
  /// those same value types. Repeated modifiers merge their dictionaries. If the same key
  /// is set more than once, the later modifier value is used.
  public func snapshotAdditionalContext(_ context: [String: Any]) -> some View {
    preference(
      key: SnapshotAdditionalContextPreferenceKey.self,
      value: SnapshotMetadataValue.dictionary(from: context)
    )
  }
}
