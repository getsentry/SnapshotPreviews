//
//  EmergeModifierFinder.swift
//
//
//  Created by Noah Martin on 10/6/23.
//

import Foundation
import SwiftUI
import SnapshotSharedModels

// Classes in this file get compiled to an app that use any of the custom preview preferences.
// The inserted test runner code finds these classes through ObjC runtime functions (NSClassFromString)
// and Swift reflection (Mirror).

@objc(EmergeModifierState)
class EmergeModifierState: NSObject {

  @objc
  static let shared = EmergeModifierState()

  func reset() {
    expansionPreference = nil
    renderingMode = nil
    precision = nil
    accessibilityEnabled = nil
    appStoreSnapshot = nil
    tags = [:]
    additionalContext = [:]
    groupOverride = nil
  }

  var expansionPreference: Bool?
  var renderingMode: EmergeRenderingMode.RawValue?
  var precision: Float?
  var accessibilityEnabled: Bool?
  var appStoreSnapshot: Bool?
  var tags: [String: String] = [:]
  var additionalContext: [String: SnapshotMetadataValue] = [:]
  var groupOverride: SnapshotGroup?
}

@objc(EmergeModifierFinder)
class EmergeModifierFinder: NSObject {
  let finder: (any View) -> (any View) = { view in
    EmergeModifierState.shared.reset()
    return view
      .onPreferenceChange(ExpansionPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.expansionPreference = value
      })
      .onPreferenceChange(RenderingModePreferenceKey.self, perform: { value in
        EmergeModifierState.shared.renderingMode = value
      })
      .onPreferenceChange(PrecisionPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.precision = value
      })
      .onPreferenceChange(AccessibilityPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.accessibilityEnabled = value
      })
      .onPreferenceChange(AppStoreSnapshotPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.appStoreSnapshot = value
      })
      .onPreferenceChange(SnapshotTagsPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.tags = value
      })
      .onPreferenceChange(SnapshotAdditionalContextPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.additionalContext = value
      })
      .onPreferenceChange(SnapshotGroupPreferenceKey.self, perform: { value in
        EmergeModifierState.shared.groupOverride = value
      })
  }
}
