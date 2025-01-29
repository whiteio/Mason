//
//  BuildConfig.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

import Foundation

struct BuildConfig {
    let appName: String
    let bundleId: String
    let sourceDir: String
    let buildDir: String
    let resourcesDir: String
    let deploymentTarget: String

    var sdkPath: String {
        "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
    }

    var simulatorArch: String {
        #if arch(arm64)
            return "arm64"
        #else
            return "x86_64"
        #endif
    }
}
