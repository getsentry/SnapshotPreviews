//
//  SnapshotMetadataValue.swift
//

import CoreFoundation
import CoreGraphics
import Foundation

public enum SnapshotMetadataValue: Sendable, Equatable, Encodable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: SnapshotMetadataValue])

  public init(_ value: Any) {
    switch value {
    case let value as SnapshotMetadataValue:
      self = value
    case let value as String:
      self = .string(value)
    case let value as Bool:
      self = .bool(value)
    case let value as Int:
      self = Self.jsonNumber(Double(value))
    case let value as Int8:
      self = Self.jsonNumber(Double(value))
    case let value as Int16:
      self = Self.jsonNumber(Double(value))
    case let value as Int32:
      self = Self.jsonNumber(Double(value))
    case let value as Int64:
      self = Self.jsonNumber(Double(value))
    case let value as UInt:
      self = Self.jsonNumber(Double(value))
    case let value as UInt8:
      self = Self.jsonNumber(Double(value))
    case let value as UInt16:
      self = Self.jsonNumber(Double(value))
    case let value as UInt32:
      self = Self.jsonNumber(Double(value))
    case let value as UInt64:
      self = Self.jsonNumber(Double(value))
    case let value as Double:
      self = Self.jsonNumber(value)
    case let value as Float:
      self = Self.jsonNumber(Double(value))
    case let value as CGFloat:
      self = Self.jsonNumber(Double(value))
    case let value as NSNumber:
      if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() {
        self = .bool(value.boolValue)
      } else {
        self = Self.jsonNumber(value.doubleValue)
      }
    case let value as [String: Any]:
      self = .object(Self.dictionary(from: value))
    default:
      preconditionFailure("Unsupported snapshot metadata value: \(type(of: value))")
    }
  }

  public static func dictionary(from values: [String: Any]) -> [String: SnapshotMetadataValue] {
    values.mapValues { SnapshotMetadataValue($0) }
  }

  private static func jsonNumber(_ value: Double) -> SnapshotMetadataValue {
    precondition(value.isFinite, "Snapshot metadata numbers must be finite JSON values.")
    return .number(value)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }
}
