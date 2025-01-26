//
//  BuildSystem.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

import Foundation

final class BuildSystem {
    private let config: BuildConfig
    private let fileManager: FileManager
    
    init(config: BuildConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
    }
    
    func build() async throws {
        try prepareDirectories()
        try await compileSwiftFiles()
        try createAppBundle()
        try processResources()
        
        print("Successfully built \(config.appName).app")
        print("App location: \(config.buildDir)/\(config.appName).app")
        
        // Install directly from .app bundle
        try installApp()
    }

    private func installApp() throws {
        // Install app
        let install = Process()
        install.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        install.arguments = [
            "simctl",
            "install",
            "booted",
            "\(config.buildDir)/\(config.appName).app"
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
            config.bundleId
        ]
        
        try launch.run()
        launch.waitUntilExit()
        
        if launch.terminationStatus == 0 {
            print("Successfully launched app in simulator")
        } else {
            throw BuildError.launchFailed("Failed to launch app in simulator")
        }
    }

    private func prepareDirectories() throws {
        try? fileManager.removeItem(atPath: config.buildDir)
        try? fileManager.removeItem(atPath: config.ipaDir)
        
        try fileManager.createDirectory(atPath: config.buildDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: config.ipaDir, withIntermediateDirectories: true)
    }
    
    private func compileSwiftFiles() async throws {
        let sources = try findSwiftFiles()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        
        // Add paths for Swift runtime libraries
        let simulatorLibPath = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator"
        let swiftLibPath = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"
        
        var args = [
            "-sdk", config.sdkPath,
            "-target", "\(config.simulatorArch)-apple-ios\(config.deploymentTarget)-simulator",
            "-emit-executable",
            "-o", "\(config.buildDir)/\(config.appName)",
            // Add Swift library search paths
            "-L", simulatorLibPath,
            "-L", swiftLibPath,
            // Runtime search paths
            "-Xlinker", "-rpath", "-Xlinker", "@executable_path/Frameworks",
            "-Xlinker", "-rpath", "-Xlinker", simulatorLibPath,
            // Framework paths
            "-F", "\(config.sdkPath)/System/Library/Frameworks",
            // Required frameworks
            "-framework", "SwiftUI",
            "-framework", "Foundation",
            "-framework", "UIKit",
            "-framework", "CoreGraphics",
            "-framework", "CoreServices",
            // Swift settings
            "-swift-version", "5",
            // Additional linker flags
            "-Xlinker", "-no_objc_category_merging"
        ]
        args += sources
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        process.arguments = args
        
        print("Compiling with arguments: \(args.joined(separator: " "))")
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("Compiler output:\n\(output)")
        }
        
        if process.terminationStatus != 0 {
            throw BuildError.compilationFailed(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }
    
    private func findSwiftFiles() throws -> [String] {
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: config.sourceDir),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        var swiftFiles: [String] = []
        
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                swiftFiles.append(url.path)
            }
        }
        
        guard !swiftFiles.isEmpty else {
            throw BuildError.compilationFailed("No Swift files found in \(config.sourceDir)")
        }
        
        return swiftFiles
    }
    
    private func createAppBundle() throws {
        let appBundlePath = "\(config.buildDir)/\(config.appName).app"
        try? fileManager.removeItem(atPath: appBundlePath)
        try fileManager.createDirectory(atPath: appBundlePath, withIntermediateDirectories: true)
        
        // Copy executable
        try fileManager.moveItem(
            atPath: "\(config.buildDir)/\(config.appName)",
            toPath: "\(appBundlePath)/\(config.appName)"
        )
        
        // Make sure permissions are correct
        try setExecutablePermissions(atPath: "\(appBundlePath)/\(config.appName)")
        
        // Sign the bundle
        try signApp(at: appBundlePath)
    }
    
    private func signApp(at path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = [
            "--force",
            "--sign", "-",  // Ad-hoc signing
            "--preserve-metadata=identifier,entitlements,flags",
            "--generate-entitlement-der",
            path
        ]
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            throw BuildError.signingFailed(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }
    
    private func processResources() throws {
        let appBundlePath = "\(config.buildDir)/\(config.appName).app"
        try createDefaultInfoPlist(at: "\(appBundlePath)/Info.plist")
    }
    
    private func createDefaultInfoPlist(at path: String) throws {
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleExecutable</key>
            <string>\(config.appName)</string>
            <key>CFBundleIdentifier</key>
            <string>\(config.bundleId)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>\(config.appName)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSRequiresIPhoneOS</key>
            <true/>
            <key>UILaunchScreen</key>
            <dict/>
            <key>UIRequiredDeviceCapabilities</key>
            <array>
                <string>arm64</string>
            </array>
            <key>UISupportedInterfaceOrientations</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
                <string>UIInterfaceOrientationLandscapeLeft</string>
                <string>UIInterfaceOrientationLandscapeRight</string>
            </array>
            <key>MinimumOSVersion</key>
            <string>\(config.deploymentTarget)</string>
            <key>DTPlatformName</key>
            <string>iphonesimulator</string>
            <key>DTPlatformVersion</key>
            <string>17.0</string>
            <key>DTSDKName</key>
            <string>iphonesimulator17.0</string>
        </dict>
        </plist>
        """
        
        try infoPlist.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    private func createIPA() throws {
        let payloadPath = "\(config.ipaDir)/Payload"
        try? fileManager.removeItem(atPath: payloadPath)
        try fileManager.createDirectory(atPath: payloadPath, withIntermediateDirectories: true)
        
        try fileManager.copyItem(
            atPath: "\(config.buildDir)/\(config.appName).app",
            toPath: "\(payloadPath)/\(config.appName).app"
        )
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = URL(fileURLWithPath: config.ipaDir)
        process.arguments = ["-r", "\(config.appName).ipa", "Payload"]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw BuildError.ipaCreationFailed("Failed to create IPA")
        }
        
        try? fileManager.removeItem(atPath: payloadPath)
    }
    
    private func setExecutablePermissions(atPath path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["755", path]
        try process.run()
        process.waitUntilExit()
    }
}
