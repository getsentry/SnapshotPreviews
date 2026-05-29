//
//  View+Snapshot.swift
//  FindPreviews
//
//  Created by Noah Martin on 12/22/22.
//

import CoreFoundation

public enum RenderingError: Error {
  case failedRendering(CGSize)
  case maxSize(CGSize)
  case expandingViewTimeout(CGSize)
  case orientationChangeTimeout
}

#if canImport(UIKit) && !os(visionOS) && !os(watchOS) && !os(tvOS)
import Foundation
import SwiftUI
import UIKit
import SnapshotSharedModels

private var _colorScheme: ColorScheme? = nil

extension View {
  public func makeExpandingView(layout: PreviewLayout, window: UIWindow) -> ExpandingViewController {
    UIView.setAnimationsEnabled(false)
    var wrappedView: any View = self.transaction { transaction in
      transaction.disablesAnimations = true
    }
    _colorScheme = nil
    wrappedView = PreferredColorSchemeWrapper {
      AnyView(wrappedView)
    } colorSchemeUpdater: { scheme in
      _colorScheme = scheme
    }
    let controller = ExpandingViewController(rootView: wrappedView)
    controller.setupView(layout: layout)

    let windowRootVC = Self.setupRootVC(subVC: controller)
    window.rootViewController = windowRootVC
    return controller
  }

  public func snapshot(
    layout: PreviewLayout,
    controller: ExpandingViewController,
    window: UIWindow,
    async: Bool,
    a11yWrapper: ((UIViewController, UIWindow, PreviewLayout) -> UIView)? = nil,
    completion: @escaping (SnapshotResult) -> Void)
  {
    controller.expansionSettled = { [weak controller, weak window] renderingMode, precision, accessibilityEnabled, appStoreSnapshot, tags, additionalContext, error in
      guard let controller, let window, let containerVC = controller.parent else {
        return
      }

      if let error {
        DispatchQueue.main.async {
          completion(SnapshotResult(image: .failure(error), precision: precision, accessibilityEnabled: accessibilityEnabled, colorScheme: _colorScheme, appStoreSnapshot: appStoreSnapshot, tags: tags, additionalContext: additionalContext))
        }
        return
      }

      if async {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          let imageResult = Self.takeSnapshot(layout: layout, renderingMode: renderingMode, window: window, rootVC: containerVC, targetView: controller.view)
          completion(SnapshotResult(image: imageResult.mapError { $0 }, precision: precision, accessibilityEnabled: accessibilityEnabled, colorScheme: _colorScheme, appStoreSnapshot: appStoreSnapshot, tags: tags, additionalContext: additionalContext))
        }
      } else {
        DispatchQueue.main.async {
          if let a11yWrapper, let accessibilityEnabled, accessibilityEnabled {
            let a11yView = a11yWrapper(controller, window, layout)
            let result = Self.takeSnapshot(layout: .sizeThatFits, renderingMode: renderingMode, window: window, rootVC: containerVC, targetView: a11yView)
            a11yView.removeFromSuperview()
            completion(SnapshotResult(image: result.mapError { $0 }, precision: precision, accessibilityEnabled: accessibilityEnabled, colorScheme: _colorScheme, appStoreSnapshot: appStoreSnapshot, tags: tags, additionalContext: additionalContext))
          } else {
            let imageResult = Self.takeSnapshot(layout: layout, renderingMode: renderingMode, window: window, rootVC: containerVC, targetView: controller.view)
            completion(SnapshotResult(image: imageResult.mapError { $0 }, precision: precision, accessibilityEnabled: accessibilityEnabled, colorScheme: _colorScheme, appStoreSnapshot: appStoreSnapshot, tags: tags, additionalContext: additionalContext))
          }
        }
      }
    }
  }

  private static func setupRootVC(subVC: UIViewController) -> UIViewController {
    let windowRootVC = UIViewController()
    windowRootVC.view.bounds = UIScreen.main.bounds
    windowRootVC.view.backgroundColor = .clear

    let containerVC = UIViewController()
    containerVC.view.backgroundColor = .clear
    containerVC.view.translatesAutoresizingMaskIntoConstraints = false
    windowRootVC.view.addSubview(containerVC.view)
    windowRootVC.addChild(containerVC)
    containerVC.didMove(toParent: windowRootVC)
    containerVC.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true
    containerVC.view.heightAnchor.constraint(greaterThanOrEqualToConstant: UIScreen.main.bounds.height).isActive = true
    containerVC.view.centerXAnchor.constraint(equalTo: windowRootVC.view.centerXAnchor).isActive = true
    containerVC.view.centerYAnchor.constraint(equalTo: windowRootVC.view.centerYAnchor).isActive = true

    containerVC.view.addSubview(subVC.view)
    containerVC.addChild(subVC)
    subVC.didMove(toParent: containerVC)

    subVC.view.centerXAnchor.constraint(equalTo: containerVC.view.centerXAnchor).isActive = true
    subVC.view.centerYAnchor.constraint(equalTo: containerVC.view.centerYAnchor).isActive = true
    subVC.view.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width).isActive = true
    containerVC.view.heightAnchor.constraint(greaterThanOrEqualTo: subVC.view.heightAnchor, multiplier: 1).isActive = true

    return windowRootVC
  }

  private static func takeSnapshot(
    layout: PreviewLayout,
    renderingMode: EmergeRenderingMode?,
    window: UIWindow,
    rootVC: UIViewController,
    targetView: UIView,
    maxSize: Double = 1_000_000,
    maxTotalPixels: Double = 40_000_000) -> Result<UIImage, RenderingError>
  {
    if renderingMode == EmergeRenderingMode.window {
      let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
      let screenshot = renderer.image { _ in
          window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
      return .success(screenshot)
    }

    let view = targetView
    let drawCode: (CGContext) -> Void

    CATransaction.commit()

    let targetSize: CGSize
    var success = false
    switch layout {
    case .fixed(width: let width, height: let height):
      targetSize = CGSize(width: width, height: height)
      drawCode = { ctx in
        success = view.render(size: targetSize, mode: renderingMode, context: ctx)
      }
    case .sizeThatFits:
      targetSize = view.bounds.size
      drawCode = { ctx in
        success = view.render(size: targetSize, mode: renderingMode, context: ctx)
      }
    case .device:
      fallthrough
    default:
      let viewSize = view.bounds.size

      targetSize = CGSize(width: UIScreen.main.bounds.size.width, height: max(viewSize.height, UIScreen.main.bounds.size.height))
      drawCode = { ctx in
        success = rootVC.view.render(size: targetSize, mode: renderingMode, context: ctx)
      }
    }
    let scale = Double(UIScreen.main.scale)
    let totalPixels = Double(targetSize.width) * scale * Double(targetSize.height) * scale
    if targetSize.height > maxSize || targetSize.width > maxSize || totalPixels > maxTotalPixels {
      return .failure(RenderingError.maxSize(targetSize))
    }
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let image = renderer.image { context in
      drawCode(context.cgContext)
    }
    if !success {
      return .failure(RenderingError.failedRendering(targetSize))
    }
    return .success(image)
  }
}

extension CGSize {
  var requiresCoreAnimationSnapshot: Bool {
    height >= UIScreen.main.bounds.size.height * 2
  }
}

extension UIView {
  func render(size: CGSize, mode: EmergeRenderingMode?, context: CGContext) -> Bool {
    switch mode {
    case .coreAnimation:
      layer.layerForSnapshot.render(in: context)
      return true
    case .uiView:
      return drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    case .window, .none:
      if !size.requiresCoreAnimationSnapshot {
        return drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
      } else {
        layer.layerForSnapshot.render(in: context)
        return true
      }
    }
  }
}

extension CALayer {

  var layerForSnapshot: Self {
    guard !hasMapView else {
      return self
    }

    return presentation() ?? self
  }

  var hasMapView: Bool {
    if type(of: self).description() == "VKMapView" {
      return true
    }
    for s in sublayers ?? [] {
      if s.hasMapView {
        return true
      }
    }
    return false
  }
}
#endif
