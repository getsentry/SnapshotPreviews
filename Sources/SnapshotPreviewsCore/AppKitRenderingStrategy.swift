//
//  AppKitRenderingStrategy.swift
//
//
//  Created by Noah Martin on 8/8/24.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import Foundation
import AppKit
import SwiftUI
import SnapshotSharedModels

class BorderlessWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: bufferingType, defer: flag)
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
    }
}

private var _colorScheme: ColorScheme? = nil

public class AppKitRenderingStrategy: RenderingStrategy {

  private let window: NSWindow

  public init() {
    window = BorderlessWindow()
    window.makeKeyAndOrderFront(nil)
  }

  @MainActor public func render(
    preview: SnapshotPreviewsCore.Preview,
    completion: @escaping (SnapshotResult) -> Void)
  {
    var wrappedView = preview.view()
    _colorScheme = nil
    wrappedView = PreferredColorSchemeWrapper {
      AnyView(wrappedView)
    } colorSchemeUpdater: { scheme in
      _colorScheme = scheme
    }
    let vc = AppKitContainer(rootView: wrappedView)
    vc.setupView(layout: preview.layout)
    // Reset the window size to default before adding the new view controller
    window.contentViewController = NSViewController()
    window.setContentSize(AppKitContainer.defaultSize)
    window.contentViewController = vc
    vc.rendered = { [weak window, weak vc] mode, precision, accessibilityEnabled, appStoreSnapshot, tags, additionalContext in
      DispatchQueue.main.async {
        Self.takeSnapshot(mode: mode ?? .nsView, viewController: vc, window: window) { image in
          completion(
            SnapshotResult(
              image: image != nil ? .success(image!) : .failure(RenderingError.failedRendering(window?.frame.size ?? .zero)),
              precision: precision,
              accessibilityEnabled: accessibilityEnabled,
              colorScheme: _colorScheme,
              appStoreSnapshot: appStoreSnapshot,
              tags: tags,
              additionalContext: additionalContext))
        }
      }
    }
  }

  private static func takeSnapshot(mode: EmergeRenderingMode, viewController: NSViewController?, window: NSWindow?, completion: @escaping (NSImage?) -> Void) {
    switch mode {
    case .coreAnimation:
        completion(viewController?.view.layerSnapshot())
    case .nsView:
      completion(viewController?.view.snapshot())
    case .window:
      if let window {
        attemptSnapshot(window: window, maxAttempts: 15, completion: completion)
      }
      else {
        completion(nil)
      }
    }
  }
  
  private static func attemptSnapshot(window: NSWindow?, maxAttempts: Int, completion: @escaping (NSImage?) -> Void) {
    guard let window = window else {
      completion(nil)
      return
    }
    
    func trySnapshot(attempt: Int) {
      let image = window.snapshot()
      
      if image != nil || attempt >= maxAttempts {
        if attempt >= maxAttempts {
          completion(nil)
        }
        completion(image)
        return
      }
      
      // Calculate exponential backoff delay: 0.01 * 2^(attempt-1)
      let baseDelay = 0.01
      let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
      
      DispatchQueue.main.asyncAfter(deadline: .now() + exponentialDelay) {
        trySnapshot(attempt: attempt + 1)
      }
    }
    
    trySnapshot(attempt: 1)
  }
}

final class AppKitContainer: NSHostingController<EmergeModifierView>, ScrollExpansionProviding {

  var supportsExpansion: Bool {
    rootView.supportsExpansion
  }
  var heightAnchor: NSLayoutConstraint?
  var previousHeight: CGFloat?

  public var rendered: ((EmergeRenderingMode?, Float?, Bool?, Bool?, [String: String], [String: SnapshotMetadataValue]) -> Void)? {
    didSet { didCall = false }
  }

  static let defaultSize = NSSize(width: 800, height: 400)

  private var didCall = false
  private var widthAnchor: NSLayoutConstraint?

  init<Content: View>(rootView: Content) {
    super.init(rootView: EmergeModifierView(wrapped: rootView))

    if #available(macOS 13.0, *) {
      sizingOptions = .intrinsicContentSize
    }
    view.translatesAutoresizingMaskIntoConstraints = false
  }

  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func removeConstraints() {
    heightAnchor?.isActive = false
    widthAnchor?.isActive = false
    heightAnchor = nil
    widthAnchor = nil
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
      let fittingSize = sizeThatFits(in: Self.defaultSize)
      widthAnchor = view.widthAnchor.constraint(equalToConstant: fittingSize.width)
      widthAnchor?.isActive = true
      heightAnchor = view.heightAnchor.constraint(equalToConstant: fittingSize.height)
      heightAnchor?.isActive = true
    }
  }

  private func runCallback() {
    guard !didCall else { return }

    didCall = true
    rendered?(rootView.emergeRenderingMode, rootView.precision, rootView.accessibilityEnabled, rootView.appStoreSnapshot, rootView.tags, rootView.additionalContext)
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()
    updateScrollViewHeight()
  }

  public func updateScrollViewHeight() {
    guard rendered != nil else {
      runCallback()
      return
    }

    updateHeight {
      runCallback()
    }
  }
}

extension NSView {
  func snapshot() -> NSImage? {
    guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else {
      return nil
    }
    bitmapRep.size = bounds.size
    cacheDisplay(in: bounds, to: bitmapRep)

    let image = NSImage(size: bounds.size)
    image.addRepresentation(bitmapRep)

    return image
  }
    
  func layerSnapshot() -> NSImage? {
    let scale = window?.backingScaleFactor ?? 1
    let height = Int(bounds.size.height * scale)
    let width = Int(bounds.size.width * scale)
    let bytesPerRow = width * 4
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return nil
    }
    
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: scale, y: -scale)

    (self.layer?.presentation() ?? self.layer)?.render(in: context)
    guard let cgImage = context.makeImage() else {
      return nil
    }
    return NSImage(cgImage: cgImage, size: bounds.size)
  }
}

extension NSWindow {
  func snapshot() -> NSImage? {
    guard let cgImage = CGWindowListCreateImage(.null,
                                                .optionIncludingWindow,
                                                CGWindowID(self.windowNumber),
                                                .bestResolution)
    else {
      return nil
    }

    return NSImage(cgImage: cgImage, size: self.frame.size)
  }
}

#endif
