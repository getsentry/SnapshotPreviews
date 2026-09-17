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

      // UIImage.pngData() can leave 16-bit colors premultiplied by alpha,
      // which creates dark edges when the PNG is displayed.
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        return nil
      }
      let properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: image.scale * 72,
        kCGImagePropertyDPIHeight: image.scale * 72,
      ]
      CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
      guard CGImageDestinationFinalize(destination) else {
        return nil
      }
      return data as Data
    }
  }
}
#endif
