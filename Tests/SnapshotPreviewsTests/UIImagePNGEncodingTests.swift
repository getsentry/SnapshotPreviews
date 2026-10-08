#if canImport(UIKit)
import ImageIO
import UIKit
import XCTest
@testable import SnapshotPreviewsCore

final class UIImagePNGEncodingTests: XCTestCase {
  func testUIKitPNGEncodingStillRequiresAlphaWorkaround() throws {
    let image = makeImage(range: .extended)
    // Deliberately use UIKit directly, rather than the workaround.
    let actual = try pixels(decode(image.pngData()))
    let expected = try pixels(XCTUnwrap(image.cgImage))
    XCTAssertEqual(actual.count, expected.count)
    XCTAssertEqual(actual[3], expected[3])

    let options = XCTExpectedFailure.Options()
    options.isStrict = true
    // Keep fixture/alpha checks outside the expected failure. Only the
    // known color error is expected; an unexpected pass flags a possible fix.
    XCTExpectFailure(
      "UIKit's extended-range PNG alpha bug: if this unexpectedly passes on a new runtime, reassess the ImageIO workaround.",
      options: options
    ) {
      for (actual, expected) in zip(actual.prefix(3), expected.prefix(3)) {
        XCTAssertEqual(Double(actual), Double(expected), accuracy: 1)
      }
    }
  }

  func testExtendedRangePNGPreservesColorAndAlpha() throws {
    // Two rows suffice to exercise UIKit's affected PNG path. Compare decoded
    // pixels in a common color space without assuming the PNG's bit depth.
    let samples: [(red: Double, green: Double, blue: Double, alpha: Double)] = [
      (0.96, 0.96, 0.96, 0.5),
      (0.8, 0.3, 0.1, 0.25),
      (0.2, 0.7, 0.9, 0.75),
      (0.2, 0.7, 0.9, 1),
    ]
    for sample in samples {
      let color = UIColor(red: sample.red, green: sample.green, blue: sample.blue, alpha: sample.alpha)
      let image = makeImage(range: .extended, color: color)
      let decoded = try decode(image.emg.pngData())

      try assertEqualPixels(decoded, XCTUnwrap(image.cgImage))
    }
  }

  func testStandardRangePNGPreservesColorAndAlpha() throws {
    let image = makeImage(range: .standard)
    let decoded = try decode(image.emg.pngData())

    try assertEqualPixels(decoded, XCTUnwrap(image.cgImage))
  }

  func testOrientedImageMatchesUIKitPNGEncoding() throws {
    let original = try XCTUnwrap(makeImage(range: .standard).cgImage)
    for orientation in [UIImage.Orientation.up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored] {
      let image = UIImage(cgImage: original, scale: 2, orientation: orientation)
      let expectedData = try XCTUnwrap(image.pngData())
      let data = try XCTUnwrap(image.emg.pngData())
      let expected = try decode(expectedData)
      let decoded = try decode(data)

      try assertEqualPixels(decoded, expected)
      // Raw CGImage decoding ignores orientation metadata, so pixel equality
      // alone would pass even if every image incorrectly reloaded as .up.
      XCTAssertEqual(try XCTUnwrap(UIImage(data: data)).imageOrientation, orientation)
      let properties = try pngProperties(data)
      let expectedProperties = try pngProperties(expectedData)
      XCTAssertEqual(
        try XCTUnwrap(properties[kCGImagePropertyOrientation] as? Int),
        try XCTUnwrap(expectedProperties[kCGImagePropertyOrientation] as? Int)
      )
    }
  }

  func testEmptyImageReturnsNil() {
    XCTAssertNil(UIImage().emg.pngData())
  }

  func testPNGPreservesImageResolution() throws {
    let original = try XCTUnwrap(makeImage(range: .standard).cgImage)
    let image = UIImage(cgImage: original, scale: 3, orientation: .up)
    let data = try XCTUnwrap(image.emg.pngData())
    let properties = try pngProperties(data)

    XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double), 216, accuracy: 0.1)
    XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIHeight] as? Double), 216, accuracy: 0.1)
  }

  private func makeImage(
    range: UIGraphicsImageRendererFormat.Range,
    color: UIColor = UIColor(white: 0.96, alpha: 0.5)
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    format.preferredRange = range
    return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2), format: format).image { context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
      // Leave the remaining pixels transparent.
    }
  }

  private func decode(_ data: Data?) throws -> CGImage {
    let data = try XCTUnwrap(data)
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
  }

  private func pngProperties(_ data: Data) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  private func assertEqualPixels(_ actual: CGImage, _ expected: CGImage, file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(actual.width, expected.width, file: file, line: line)
    XCTAssertEqual(actual.height, expected.height, file: file, line: line)
    let actualPixels = try pixels(actual)
    let expectedPixels = try pixels(expected)
    XCTAssertEqual(actualPixels.count, expectedPixels.count, file: file, line: line)
    for (actual, expected) in zip(actualPixels, expectedPixels) {
      XCTAssertEqual(Double(actual), Double(expected), accuracy: 1, file: file, line: line)
    }
  }

  private func pixels(_ image: CGImage) throws -> [UInt8] {
    let context = try XCTUnwrap(CGContext(
      data: nil,
      width: image.width,
      height: image.height,
      bitsPerComponent: 8,
      bytesPerRow: image.width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let normalized = try XCTUnwrap(context.makeImage())
    let data = try XCTUnwrap(normalized.dataProvider?.data)
    return Array(data as Data)
  }
}
#endif
