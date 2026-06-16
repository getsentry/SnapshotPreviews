//
//  SnapshotGroup.swift
//

import Foundation

/// Strategy for the top-level `group` field written to a snapshot's JSON sidecar.
public enum SnapshotGroup: Sendable, Equatable {
  /// Use the generated group. Equivalent to not overriding the group.
  case `default`
  /// Use a custom group name.
  case custom(String)
  /// Use the module name from the preview container's type name.
  case module
}
