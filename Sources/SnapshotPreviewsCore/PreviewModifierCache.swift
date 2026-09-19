//
//  PreviewModifierCache.swift
//  SnapshotPreviews
//
//  Created by Itay Brenner on 25/9/24.
//

import SwiftUI

struct PreviewModifierContextCache {
  static let shared = PreviewModifierContextCache()
  
  static var contextCache: [String: Any] = [:]
}
