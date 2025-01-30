//
//  AppConfig.swift
//  mason
//
//  Created by Chris White on 1/30/25.
//

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
