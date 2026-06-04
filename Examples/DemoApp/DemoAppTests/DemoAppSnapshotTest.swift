//
//  DemoAppSnapshotTest.swift
//  DemoAppTests
//
//  Created by Noah Martin on 8/10/24.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AccessibilitySnapshotCore)
import AccessibilitySnapshotCore
#endif
import SnapshottingTests

class DemoAppSnapshotTest: SnapshotTest {
  override class func snapshotPreviews() -> [String]? {
    return nil
  }

  override class func excludedSnapshotPreviews() -> [String]? {
    return nil
  }

  override class func snapshotPreviewModules() -> [String]? {
    return nil
  }

  override class func excludedSnapshotPreviewModules() -> [String]? {
    return nil
  }

  #if canImport(UIKit) && canImport(AccessibilitySnapshotCore) && !os(watchOS) && !os(visionOS) && !os(tvOS)
  override open class func setupA11y() -> ((UIViewController, UIWindow, PreviewLayout) -> UIView)? {
    return { (controller: UIViewController, window: UIWindow, layout: PreviewLayout) in
      let containerVC = controller.parent
      let containedView: UIView
      switch layout {
      case .device:
        containedView = containerVC?.view ?? controller.view
      default:
        containedView = controller.view
      }
      let a11yView = AccessibilitySnapshotView(
        containedView: containedView,
        viewRenderingMode: controller.view.bounds.size.requiresCoreAnimationSnapshot ? .renderLayerInContext : .drawHierarchyInRect,
        activationPointDisplayMode: .never,
        showUserInputLabels: true)

      a11yView.center = window.center
      window.addSubview(a11yView)

      _ = try? a11yView.parseAccessibility(useMonochromeSnapshot: false)
      a11yView.sizeToFit()
      return a11yView
    }
  }
  #endif
}

#if canImport(UIKit)
extension CGSize {
  var requiresCoreAnimationSnapshot: Bool {
    height >= UIScreen.main.bounds.size.height * 2
  }
}
#endif
