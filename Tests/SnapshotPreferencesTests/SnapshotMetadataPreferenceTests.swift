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

  func testGroupPreferenceDefaultsToNil() {
    XCTAssertNil(SnapshotGroupPreferenceKey.defaultValue)
  }

  func testGroupPreferenceLaterValueWins() {
    var value = SnapshotGroupPreferenceKey.defaultValue

    SnapshotGroupPreferenceKey.reduce(value: &value) { .custom("First") }
    SnapshotGroupPreferenceKey.reduce(value: &value) { .custom("Second") }

    XCTAssertEqual(value, .custom("Second"))
  }

  func testGroupPreferenceKeepsCurrentValueWhenNextValueIsNil() {
    var value = SnapshotGroupPreferenceKey.defaultValue

    SnapshotGroupPreferenceKey.reduce(value: &value) { .custom("Checkout") }
    SnapshotGroupPreferenceKey.reduce(value: &value) { nil }

    XCTAssertEqual(value, .custom("Checkout"))
  }

  func testGroupPreferenceStoresCustomString() {
    var value = SnapshotGroupPreferenceKey.defaultValue

    SnapshotGroupPreferenceKey.reduce(value: &value) { .custom("Checkout") }

    XCTAssertEqual(value, .custom("Checkout"))
  }

  func testGroupPreferenceStoresDefaultStrategy() {
    var value = SnapshotGroupPreferenceKey.defaultValue

    SnapshotGroupPreferenceKey.reduce(value: &value) { .default }

    XCTAssertEqual(value, .default)
  }

  func testGroupPreferenceStoresModuleStrategy() {
    var value = SnapshotGroupPreferenceKey.defaultValue

    SnapshotGroupPreferenceKey.reduce(value: &value) { .module }

    XCTAssertEqual(value, .module)
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
