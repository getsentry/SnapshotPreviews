//
//  UIImage+EMG.swift
//
//
//  Created by Noah Martin on 8/8/24.
//

#if canImport(UIKit)
import ImageIO
import UIKit
import UniformTypeIdentifiers

public extension UIImage {
  var emg: UIImageSnapshotsNamespace {
    .init(image: self)
  }

  struct UIImageSnapshotsNamespace {
    private let image: UIImage

    init(image: UIImage) {
      self.image = image
    }

    public func pngData() -> Data? {
      guard let cgImage = image.cgImage else {
        return image.pngData()
      }

      // UIKit's 16-bit PNG path can leave colors premultiplied by alpha.
      // ImageIO's default options avoid that path and the resulting dark edges.
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil
      ) else {
        return nil
      }

      // Preserve UIKit's resolution metadata: scale 1 corresponds to 72 DPI.
      let dpi = image.scale * 72
      let properties: [CFString: Any] = [
        kCGImagePropertyOrientation: pngOrientation.rawValue,
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
      ]
      CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

      guard CGImageDestinationFinalize(destination) else {
        return nil
      }
      return data as Data
    }

    // UIImage and ImageIO use different orientation raw values.
    private var pngOrientation: CGImagePropertyOrientation {
      switch image.imageOrientation {
      case .up: return .up
      case .down: return .down
      case .left: return .left
      case .right: return .right
      case .upMirrored: return .upMirrored
      case .downMirrored: return .downMirrored
      case .leftMirrored: return .leftMirrored
      case .rightMirrored: return .rightMirrored
      @unknown default: return .up
      }
    }
  }
}
#endif
