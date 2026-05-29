//
//  ExpandingViewController.swift
//  TestAppSwiftUI
//
//  Created by Noah Martin on 6/30/23.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import SnapshotSharedModels

#if canImport(UIKit) && !os(visionOS) && !os(watchOS) && !os(tvOS)

public final class ExpandingViewController: UIHostingController<EmergeModifierView>, ScrollExpansionProviding {

  var supportsExpansion: Bool {
    rootView.supportsExpansion
  }

  private let HeightExpansionTimeLimitInSeconds: UInt64 = 30

  private var didCall = false
  var previousHeight: CGFloat?

  var heightAnchor: NSLayoutConstraint?
  private var widthAnchor: NSLayoutConstraint?

  private var startTime: UInt64?
  private var timer: Timer?

  public var expansionSettled: ((EmergeRenderingMode?, Float?, Bool?, Bool?, [String: String], [String: SnapshotMetadataValue], Error?) -> Void)? {
    didSet { didCall = false }
  }

  init<Content: View>(rootView: Content) {
    super.init(rootView: EmergeModifierView(wrapped: rootView))

    if #available(iOS 16, *) {
      sizingOptions = .intrinsicContentSize
    }
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .clear
  }

  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func removeConstraints() {
    heightAnchor?.isActive = false
    widthAnchor?.isActive = false
    heightAnchor = nil
    widthAnchor = nil
    previousHeight = nil
  }

  public func setupView(layout: PreviewLayout) {
    removeConstraints()
    switch layout {
    case let .fixed(width: width, height: height):
      widthAnchor = view.widthAnchor.constraint(equalToConstant: width)
      widthAnchor?.isActive = true
      heightAnchor = view.heightAnchor.constraint(equalToConstant: height)
      heightAnchor?.isActive = true
    default:
      let fittingSize = sizeThatFits(in: UIScreen.main.bounds.size)
      widthAnchor = view.widthAnchor.constraint(greaterThanOrEqualToConstant: fittingSize.width)
      widthAnchor?.isActive = true
      heightAnchor = view.heightAnchor.constraint(greaterThanOrEqualToConstant: fittingSize.height)
      heightAnchor?.isActive = true
    }
  }

  private func runCallback(_ error: Error? = nil) {
    guard !didCall else { return }

    didCall = true
    expansionSettled?(rootView.emergeRenderingMode, rootView.precision, rootView.accessibilityEnabled, rootView.appStoreSnapshot, rootView.tags, rootView.additionalContext, error)
    stopAndResetTimer()
  }

  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateScrollViewHeight()
  }

  public func updateScrollViewHeight() {
    // Timeout limit
    if timer == nil && heightAnchor != nil && supportsExpansion && firstScrollView != nil {
      startTimer()
    }

    guard expansionSettled != nil else {
      runCallback()
      return
    }

    updateHeight {
      runCallback()
    }
  }

//  MARK: - Timer

  func startTimer() {
      guard timer == nil else {
        print("Timer already exists")
        return
      }
      startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
          guard let self,
                let start = startTime,
                clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - start >= (HeightExpansionTimeLimitInSeconds * 1_000_000_000) else {
              return
          }
          let timeoutError = RenderingError.expandingViewTimeout(CGSize(width: UIScreen.main.bounds.size.width,
                                                                        height: firstScrollView?.visibleContentHeight ?? -1))
          NSLog("ExpandingViewController: Expanding Scroll View timed out. Current height is \(firstScrollView?.visibleContentHeight ?? -1)")
          runCallback(timeoutError)
      }
  }

  func stopAndResetTimer() {
      timer?.invalidate()
      timer = nil
      startTime = nil
  }

}
#endif
