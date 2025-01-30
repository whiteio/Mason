//
//  YAMLParser.swift
//  mason
//
//  Created by Chris White on 1/27/25.
//

import Yams

enum YAMLParser {
  static func parseAppConfig(from filePath: String) throws -> AppConfig {
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    let decoder = YAMLDecoder()
    return try decoder.decode(AppConfig.self, from: content)
  }

  static func parseModuleConfig(from filePath: String) throws -> ModuleConfig {
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    let decoder = YAMLDecoder()
    return try decoder.decode(ModuleConfig.self, from: content)
  }
}
