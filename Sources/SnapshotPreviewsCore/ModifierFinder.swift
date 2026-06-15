//
//  ModifierFinder.swift
//
//
//  Created by Noah Martin on 7/8/24.
//

import Foundation
import SwiftUI
import SnapshotSharedModels

private let modifierFinderClass = (NSClassFromString("EmergeModifierFinder") as? NSObject.Type)?.init()
private let finder = modifierFinderClass != nil ? Mirror(reflecting: modifierFinderClass!).descendant("finder") as? (any View) -> any View : nil
private let modifierState = NSClassFromString("EmergeModifierState") as? NSObject.Type
private let stateMirror = modifierState != nil ? Mirror(
  reflecting: modifierState!
    .perform(NSSelectorFromString("shared"))
    .takeUnretainedValue()) : nil

public struct EmergeModifierView: View {

  private let internalView: AnyView

  init(wrapped: some View) {
    let rootView = finder?(wrapped)
    internalView = rootView != nil ? AnyView(rootView!) : AnyView(wrapped)
  }

  public var body: some View {
    internalView
  }

  var emergeRenderingMode: EmergeRenderingMode? {
    let renderingMode = stateMirror?.descendant("renderingMode") as? EmergeRenderingMode.RawValue
    return renderingMode != nil ? EmergeRenderingMode(rawValue: renderingMode!) : nil
  }

  var accessibilityEnabled: Bool? {
    stateMirror?.descendant("accessibilityEnabled") as? Bool
  }

  var appStoreSnapshot: Bool? {
    stateMirror?.descendant("appStoreSnapshot") as? Bool
  }

  var precision: Float? {
    stateMirror?.descendant("precision") as? Float
  }

  var tags: [String: String] {
    stateMirror?.descendant("tags") as? [String: String] ?? [:]
  }

  var additionalContext: [String: SnapshotMetadataValue] {
    stateMirror?.descendant("additionalContext") as? [String: SnapshotMetadataValue] ?? [:]
  }

  var groupOverride: SnapshotGroup? {
    stateMirror?.descendant("groupOverride") as? SnapshotGroup
  }

  var supportsExpansion: Bool {
    stateMirror?.descendant("expansionPreference") as? Bool ?? true
  }
}
