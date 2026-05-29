//
//  SnapshotMetadataPreferenceTests.swift
//

import XCTest
@testable import SnapshotPreferences
import SnapshotSharedModels

final class SnapshotMetadataPreferenceTests: XCTestCase {
  func testTagsPreferenceMergesWithLaterValuesWinning() {
    var value = SnapshotTagsPreferenceKey.defaultValue

    SnapshotTagsPreferenceKey.reduce(value: &value) {
      ["component": "button", "state": "loading"]
    }
    SnapshotTagsPreferenceKey.reduce(value: &value) {
      ["state": "loaded", "theme": "dark"]
    }

    XCTAssertEqual(value["component"], "button")
    XCTAssertEqual(value["state"], "loaded")
    XCTAssertEqual(value["theme"], "dark")
  }

  func testAdditionalContextPreferenceMergesWithLaterValuesWinning() {
    var value = SnapshotAdditionalContextPreferenceKey.defaultValue

    SnapshotAdditionalContextPreferenceKey.reduce(value: &value) {
      ["test_name": .string("generated"), "attempt": .number(1)]
    }
    SnapshotAdditionalContextPreferenceKey.reduce(value: &value) {
      ["test_name": .string("custom"), "is_retry": .bool(true)]
    }

    XCTAssertEqual(value["test_name"], .string("custom"))
    XCTAssertEqual(value["attempt"], .number(1))
    XCTAssertEqual(value["is_retry"], .bool(true))
  }

  func testMetadataValueConvertsSupportedPublicTypes() {
    let metadata = SnapshotMetadataValue.dictionary(from: [
      "string": "value",
      "int": 1,
      "double": 1.5,
      "bool": true,
      "nested": ["key": "nested-value"],
    ])

    XCTAssertEqual(metadata["string"], .string("value"))
    XCTAssertEqual(metadata["int"], .number(1))
    XCTAssertEqual(metadata["double"], .number(1.5))
    XCTAssertEqual(metadata["bool"], .bool(true))
    XCTAssertEqual(metadata["nested"], .object(["key": .string("nested-value")]))
  }
}
