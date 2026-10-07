#if canImport(UIKit)
import ImageIO
import UIKit
import XCTest
import zlib
@testable import SnapshotPreviewsCore

final class UIImagePNGEncodingTests: XCTestCase {
  func testUIKitPNGEncodingStillRequiresAlphaWorkaround() throws {
    let image = makeImage(range: .extended)
    XCTAssertEqual(try XCTUnwrap(image.cgImage).bitsPerComponent, 16)
    // Deliberately use UIKit directly, rather than the workaround.
    let pixel = try pngPixel(XCTUnwrap(image.pngData()))
    XCTAssertEqual(Double(pixel[3]) / 65535, 0.5, accuracy: 0.001)
    let colorError = try XCTUnwrap(pixel.prefix(3).map {
      abs(Double($0) / 65535 - 0.96)
    }.max())

    let options = XCTExpectedFailure.Options()
    options.isStrict = true
    // Keep fixture/format/alpha checks outside the expected failure. Only the
    // known color error is expected; an unexpected pass flags a possible fix.
    XCTExpectFailure(
      "UIKit's extended-range PNG alpha bug: if this unexpectedly passes on a new runtime, reassess the ImageIO workaround.",
      options: options
    ) {
      XCTAssertLessThanOrEqual(colorError, 0.001)
    }
  }

  func testExtendedRangePNGPreservesColorAndAlpha() throws {
    // Two rows suffice to exercise UIKit's affected PNG path. Keep this
    // independent of device dimensions, screen scale, and decoder behavior.
    let samples: [(red: Double, green: Double, blue: Double, alpha: Double)] = [
      (0.96, 0.96, 0.96, 0.5),
      (0.8, 0.3, 0.1, 0.25),
      (0.2, 0.7, 0.9, 0.75),
      (0.2, 0.7, 0.9, 1),
    ]
    for sample in samples {
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = false
      format.preferredRange = .extended
      let color = UIColor(red: sample.red, green: sample.green, blue: sample.blue, alpha: sample.alpha)
      let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
      }
      let source = try XCTUnwrap(image.cgImage)
      XCTAssertEqual(source.bitsPerComponent, 16)
      let data = try XCTUnwrap(image.emg.pngData())
      let decoded = try decode(data)
      // ImageIO may choose Display P3 for the PNG. Compare against the input
      // color converted into the encoded profile, not assumed sRGB samples.
      let expectedColor = try XCTUnwrap(color.cgColor.converted(
        to: XCTUnwrap(decoded.colorSpace), intent: .defaultIntent, options: nil
      ))
      let expectedComponents = try XCTUnwrap(expectedColor.components)
      XCTAssertEqual(expectedComponents.count, 4)
      let pixel = try pngPixel(data)

      // PNG stores straight color, even though the source CGImage is premultiplied.
      for (channel, expected) in zip(pixel, expectedComponents) {
        XCTAssertEqual(Double(channel) / 65535, Double(expected), accuracy: 0.001)
      }
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

  private func makeImage(range: UIGraphicsImageRendererFormat.Range) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    format.preferredRange = range
    return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2), format: format).image { context in
      UIColor(white: 0.96, alpha: 0.5).setFill()
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

  private func pngPixel(_ data: Data) throws -> [UInt16] {
    // Inspect stored samples directly, independent of decoder alpha handling.
    let bytes = [UInt8](data)
    let width = bytes[16..<20].reduce(0) { ($0 << 8) | Int($1) }
    let height = bytes[20..<24].reduce(0) { ($0 << 8) | Int($1) }
    XCTAssertEqual(bytes[24], 16)
    XCTAssertEqual(bytes[25], 6)
    XCTAssertEqual(bytes[28], 0)
    var compressed = [UInt8]()
    var offset = 8
    while offset + 12 <= bytes.count {
      let length = bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
      if Array(bytes[offset + 4..<offset + 8]) == Array("IDAT".utf8) {
        compressed.append(contentsOf: bytes[offset + 8..<offset + 8 + length])
      }
      offset += length + 12
    }
    // All PNG filters leave the first pixel of the first row unchanged
    // because its neighbors are zero.
    var row = [UInt8](repeating: 0, count: (width * 8 + 1) * height)
    var length = uLongf(row.count)
    XCTAssertEqual(uncompress(&row, &length, compressed, uLong(compressed.count)), Z_OK)
    XCTAssertEqual(length, uLongf(row.count))
    return stride(from: 1, to: 9, by: 2).map { UInt16(row[$0]) << 8 | UInt16(row[$0 + 1]) }
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
