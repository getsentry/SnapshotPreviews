import XCTest
@testable import SnapshottingTests

final class FileNameUtilsTests: XCTestCase {
  func testImageFileNameReplacesUnsafeCharacters() {
    let result = FileNameUtils.imageFileName(from: "My/View:Preview 1")

    XCTAssertEqual(result, "My_View_Preview_1.png")
  }

  func testImageFileNameIsDeterministic() {
    let a = FileNameUtils.imageFileName(from: "Some/View:Name")
    let b = FileNameUtils.imageFileName(from: "Some/View:Name")

    XCTAssertEqual(a, b)
  }

  func testImageFileNameCollapsesRepeatedUnsafeCharacters() {
    let result = FileNameUtils.imageFileName(from: "A///B   C")

    XCTAssertEqual(result, "A_B_C.png")
  }

  func testImageFileNamePreservesExistingUnderscores() {
    let result = FileNameUtils.imageFileName(from: "A___B")

    XCTAssertEqual(result, "A___B.png")
  }

  func testImageFileNameFallsBackForEmptyResult() {
    let result = FileNameUtils.imageFileName(from: "///")

    XCTAssertEqual(result, "snapshot.png")
  }

  func testImageFileNamePreservesAlphanumericAndSafeCharacters() {
    let result = FileNameUtils.imageFileName(from: "Hello_World-2.0")

    XCTAssertEqual(result, "Hello_World-2.0.png")
  }
}
