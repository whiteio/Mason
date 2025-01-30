//
//  PlistValue.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation

enum PlistValue: Codable {
  case string(String)
  case bool(Bool)
  case integer(Int)
  case array([PlistValue])
  case dictionary([String: PlistValue])

  // MARK: Lifecycle

  /// Custom decoding to handle YAML types
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let str = try? container.decode(String.self) {
      self = .string(str)
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let int = try? container.decode(Int.self) {
      self = .integer(int)
    } else if let arr = try? container.decode([PlistValue].self) {
      self = .array(arr)
    } else if let dict = try? container.decode([String: PlistValue].self) {
      self = .dictionary(dict)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid plist value")
    }
  }

  // MARK: Internal

  /// Custom encoding to match plist format
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let str): try container.encode(str)
    case .bool(let bool): try container.encode(bool)
    case .integer(let int): try container.encode(int)
    case .array(let arr): try container.encode(arr)
    case .dictionary(let dict): try container.encode(dict)
    }
  }

}
