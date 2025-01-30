//
//  YAMLParser.swift
//  mason
//
//  Created by Chris White on 1/27/25.
//

import Yams

// MARK: - AppConfig

struct AppConfig: Codable {
  let appName: String
  let bundleId: String
  let sourceDir: String
  let resourcesDir: String
  let deploymentTarget: String
  let swiftVersion: String
  let modules: [String]
  let plist: PlistConfig
  
  enum CodingKeys: String, CodingKey {
      case appName = "app-name"
      case bundleId = "bundle-id"
      case sourceDir = "source-dir"
      case resourcesDir = "resources-dir"
      case deploymentTarget = "deployment-target"
      case modules
      case swiftVersion = "swift-version"
    case plist
  }
}

struct PlistConfig: Codable {
        var version: String
        var buildNumber: String
        var infoPlist: InfoPlistConfig
        
        enum CodingKeys: String, CodingKey {
            case version
            case buildNumber = "build-number"
            case infoPlist = "info-plist"
        }
    }

// MARK: - ModuleConfig

struct ModuleConfig: Codable {
  let moduleName: String
  let dependencies: [String]?
  let sourceDir: String
  let resourcesDir: String
  
  enum CodingKeys: String, CodingKey {
    case moduleName = "module-name"
    case dependencies
    case sourceDir = "source-dir"
    case resourcesDir = "resources-dir"
  }
}

// MARK: - YAMLParser

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
