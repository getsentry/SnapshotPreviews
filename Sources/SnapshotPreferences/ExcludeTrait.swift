import SwiftUI
import SnapshotSharedModels

@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
extension PreviewTrait where T == Preview.ViewTraits {
    public static func snapshotExcluded(_ excluded: Bool) -> Self {
        .modifier(excluded ? SnapshotInclusionMode.excluded : .automatic)
    }

    public static var snapshotExcluded: Self {
        .snapshotExcluded(true)
    }
}

extension SnapshotInclusionMode: @retroactive PreviewModifier {
    public func body(content: Content, context: Void) -> some View {
        content
    }
}
