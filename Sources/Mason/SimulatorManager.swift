//
//  SimulatorManager.swift
//  mason
//
//  Created by Chris White on 1/26/25.
//

import Foundation

class SimulatorManager {
    func install(_ config: BuildConfig) throws {
        // Install app
        let install = Process()
        install.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        install.arguments = [
            "simctl",
            "install",
            "booted",
            "\(config.buildDir)/\(config.appName).app",
        ]

        try install.run()
        install.waitUntilExit()

        if install.terminationStatus != 0 {
            throw BuildError.installationFailed("Failed to install app to simulator")
        }

        print("Successfully installed app to simulator")

        // Launch app
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        launch.arguments = [
            "simctl",
            "launch",
            "booted",
            config.bundleId,
        ]

        try launch.run()
        launch.waitUntilExit()

        if launch.terminationStatus == 0 {
            print("Successfully launched app in simulator")
        } else {
            throw BuildError.launchFailed("Failed to launch app in simulator")
        }
    }
}
