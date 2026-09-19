//
//  PreviewsSupport.swift
//  PreviewsSupport
//
//  Created by Noah Martin on 10/18/23.
//

import SwiftUI
private import DeveloperToolsSupport
#if canImport(UIKit)
import UIKit
#endif

public protocol MakeViewProvider {
  var makeView: @MainActor () -> any View { get }
}

#if canImport(UIKit) && !os(watchOS)
public protocol MakeUIViewProvider {
  var makeView: @MainActor () -> UIView { get }
}

public protocol MakeViewControllerProvider {
  var makeViewController: @MainActor () -> UIViewController { get }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
@_spi(Private)
extension UIViewPreviewSource: MakeUIViewProvider { }

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
@_spi(Private)
extension UIViewControllerPreviewSource: MakeViewControllerProvider { }
#endif

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@_spi(Private)
extension ViewPreviewSource: MakeViewProvider { }

@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@_spi(Private)
extension DefaultPreviewSource: MakeViewProvider where A == SwiftUI.ViewPreviewBody {
  public var makeView: @MainActor () -> any View {
    switch structure {
    case .singlePreview(let makeBody):
      return {
        makeBody().body
      }
    // These cases return a placeholder view
    @unknown default:
      return {
        Text("Unhandled SwiftUI case in DefaultPreviewSource")
      }
    }
  }
}

#if canImport(UIKit) && !os(watchOS)
@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@_spi(Private)
extension DefaultPreviewSource: MakeUIViewProvider where A == UIView {
  public var makeView: @MainActor () -> UIView {
    switch structure {
    case .singlePreview(let makeBody):
      return makeBody
    // These cases return a placeholder view
    @unknown default:
      return {
        let label = UILabel()
        label.text = "Unhandled UIView case in DefaultPreviewSource"
        return label
      }
    }
  }
}

class UnhandledViewController: UIViewController {
  let label = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    label.text = "Unhandled UIViewController case in DefaultPreviewSource"
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    label.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
  }
}


@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@_spi(Private)
extension DefaultPreviewSource: MakeViewControllerProvider where A == UIViewController {
  public var makeViewController: @MainActor () -> UIViewController {
    switch structure {
    case .singlePreview(let makeBody):
      return makeBody
    // These cases return a placeholder view
    @unknown default:
      return {
        UnhandledViewController()
      }
    }
  }
}

#endif

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
public struct AnyViewModifier<M: PreviewModifier>: ViewModifier where M.Context == Void {
  private var modifier: M

  public init(_ modifier: M) {
   self.modifier = modifier
  }

  public func body(content: Content) -> some View {
   content
     .modifier(PreviewModifierViewModifier(modifier: modifier, context: ()))
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
public enum PreviewModifierSupport {
  public static func toViewModifier<A: PreviewModifier>(modifier: A) -> AnyViewModifier<A> where A.Context == Void {
    return AnyViewModifier(modifier)
  }
}
