//
//  PlistConfig.swift
//  mason
//
//  Created by Chris White on 1/30/25.
//

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
