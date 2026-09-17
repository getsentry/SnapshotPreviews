#if canImport(UIKit)
import ImageIO
import UIKit
import XCTest
import zlib
@testable import SnapshotPreviewsCore

final class UIImagePNGEncodingTests: XCTestCase {
  func testExtendedRangePNGPreservesColorAndAlpha() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    format.preferredRange = .extended
    // Use a screen-sized image: UIKit's PNG encoding path depends on image size.
    let image = UIGraphicsImageRenderer(size: CGSize(width: 402, height: 874), format: format).image { context in
      UIColor(white: 0.96, alpha: 0.5).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    let data = try XCTUnwrap(image.emg.pngData())
    let pixel = try pngPixel(data)

    // PNG stores straight color, even though the source CGImage is premultiplied.
    for channel in pixel.prefix(3) {
      XCTAssertEqual(Double(channel) / 65535, 0.96, accuracy: 0.001)
    }
    XCTAssertEqual(Double(pixel[3]) / 65535, 0.5, accuracy: 0.001)
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
      let expected = try decode(image.pngData())
      let decoded = try decode(image.emg.pngData())

      try assertEqualPixels(decoded, expected)
    }
  }

  func testEmptyImageReturnsNil() {
    XCTAssertNil(UIImage().emg.pngData())
  }

  func testPNGPreservesImageResolution() throws {
    let original = try XCTUnwrap(makeImage(range: .standard).cgImage)
    let image = UIImage(cgImage: original, scale: 3, orientation: .up)
    let data = try XCTUnwrap(image.emg.pngData())
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

    XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double), 216, accuracy: 0.1)
    XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIHeight] as? Double), 216, accuracy: 0.1)
  }

  private func makeImage(range: UIGraphicsImageRendererFormat.Range) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.preferredRange = range
    return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 1), format: format).image { context in
      UIColor(white: 0.96, alpha: 0.5).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
      UIColor.red.withAlphaComponent(0.25).setFill()
      context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
      UIColor.blue.setFill()
      context.fill(CGRect(x: 2, y: 0, width: 1, height: 1))
      // Leave the last pixel transparent.
    }
  }

  private func decode(_ data: Data?) throws -> CGImage {
    let data = try XCTUnwrap(data)
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
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
    let data = try XCTUnwrap(context.data)
    return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
  }
}
#endif
