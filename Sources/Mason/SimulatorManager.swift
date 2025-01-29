//
//  SimulatorManager.swift
//  mason
//
//  Created by Chris White on 1/26/25.
//

import Foundation

class SimulatorManager {
    private func runSimCtlCommand(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return (process.terminationStatus, output)
    }
    
    private func terminateApp(_ bundleId: String) throws {
        print("Terminating any existing instances of \(bundleId)...")
        let (status, output) = try runSimCtlCommand(["terminate", "booted", bundleId])
        
        // Status 146 means app wasn't running, which is fine
        if status != 0 && status != 146 {
            print("Warning: Failed to terminate app: \(output)")
        }
    }
    
    func install(_ config: BuildConfig) throws {
        // First terminate any existing instances
        try terminateApp(config.bundleId)
        
        // Install app
        print("Installing \(config.appName).app...")
        let (installStatus, installOutput) = try runSimCtlCommand([
            "install",
            "booted",
            "\(config.buildDir)/\(config.appName).app"
        ])
        
        if installStatus != 0 {
            throw BuildError.installationFailed("Failed to install app: \(installOutput)")
        }
        
        print("Successfully installed app to simulator")
        
        // Launch app
        print("Launching \(config.bundleId)...")
        let (launchStatus, launchOutput) = try runSimCtlCommand([
            "launch",
            "booted",
            config.bundleId
        ])
        
        if launchStatus != 0 {
            throw BuildError.launchFailed("Failed to launch app: \(launchOutput)")
        }
        
        print("Successfully launched app in simulator")
    }
}
