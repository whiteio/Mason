//
//  InfoPlistConfig.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

struct InfoPlistConfig: Codable {
    var customEntries: [String: PlistValue]
    var supportedOrientations: [String]
    var requiredDeviceCapabilities: [String]
    var launchScreen: Bool
    
    enum CodingKeys: String, CodingKey {
        case customEntries = "custom-entries"
        case supportedOrientations = "supported-orientations"
        case requiredDeviceCapabilities = "required-device-capabilities"
        case launchScreen = "launch-screen"
    }
}
