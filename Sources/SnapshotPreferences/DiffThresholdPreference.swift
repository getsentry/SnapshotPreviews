//
//  DiffThresholdPreference.swift
//
//
//  Created by Cameron Cooke on 4/20/26.
//

import Foundation
import SwiftUI

extension View {
    /// Sets the allowed diff threshold for the snapshot on the view.
    ///
    /// Use this method to control how much difference is tolerated when comparing snapshots.
    /// With a diff threshold of `0.0`, snapshots must match exactly. With a diff threshold of
    /// `1.0`, the snapshot will never be flagged for having differences.
    ///
    /// - Parameter diffThreshold: A Float value representing the allowed diff threshold for
    ///   snapshot comparison. If `nil`, the default behavior is used.
    ///
    /// - Returns: A view with the snapshot diff threshold preference applied.
    ///
    /// # Example
    /// ```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         Image("sample")
    ///             .snapshotDiffThreshold(0.2)
    ///     }
    /// }
    /// ```
    public func snapshotDiffThreshold(_ diffThreshold: Float?) -> some View {
        preference(key: PrecisionPreferenceKey.self, value: diffThreshold.map { 1 - $0 })
    }

    @available(*, deprecated, renamed: "snapshotDiffThreshold(_:)")
    public func diffThreshold(_ diffThreshold: Float?) -> some View {
        snapshotDiffThreshold(diffThreshold)
    }
}
