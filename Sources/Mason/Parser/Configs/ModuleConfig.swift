//
//  ModuleConfig.swift
//  mason
//
//  Created by Chris White on 1/30/25.
//

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
