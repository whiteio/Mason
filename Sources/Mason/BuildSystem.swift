//
//  BuildSystem.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

import Algorithms
import Foundation

// MARK: - BuildSystem

final class BuildSystem {

  // MARK: Lifecycle

  init(
    config: BuildConfig,
    fileManager: FileManager = .default,
    simulatorManager: SimulatorManager,
    dependencyGraph: DependencyGraph,
    useCache: Bool)
  {
    self.config = config
    self.fileManager = fileManager
    self.simulatorManager = simulatorManager
    self.dependencyGraph = dependencyGraph
    self.useCache = useCache
  }

  // MARK: Internal

  func buildApp() async throws {
    BuildTimer.reset()
    BuildTimer.start("Total Build")

    BuildTimer.start("Prepare Directories")
    try prepareDirectories()
    BuildTimer.end("Prepare Directories")

    BuildTimer.start("Module Compilation")
    let buildOrder = resolveBuildOrder()
    for moduleName in buildOrder {
      BuildTimer.start("Module: \(moduleName)")
      try await buildModule(moduleName)
      BuildTimer.end("Module: \(moduleName)")
    }
    BuildTimer.end("Module Compilation")

    BuildTimer.start("Final Link")
    try await compileAndLink()
    BuildTimer.end("Final Link")

    BuildTimer.start("Bundle Creation")
    try createAppBundle()
    try processResources()
    BuildTimer.end("Bundle Creation")

    BuildTimer.start("Installation")
    try simulatorManager.install(config)
    BuildTimer.end("Installation")

    BuildTimer.end("Total Build")
    BuildTimer.summarize()
  }

  func buildSingleModule(_ moduleName: String) async throws {
    BuildTimer.reset()
    BuildTimer.start("Module Build")

    BuildTimer.start("Prepare Directories")
    try prepareDirectories()
    BuildTimer.end("Prepare Directories")

    BuildTimer.start("Dependency Resolution")
    let dependencies = dependencyGraph.resolveDependencies(for: moduleName)
    // Remove the target module from dependencies as we'll build it last
    let moduleDependencies = dependencies.filter { $0 != moduleName }
    BuildLogger.debug("Dependencies for \(moduleName): \(moduleDependencies)")
    BuildTimer.end("Dependency Resolution")

    BuildTimer.start("Dependencies Compilation")
    for dependency in moduleDependencies {
      BuildTimer.start("Dependency: \(dependency)")
      try await buildModule(dependency)
      BuildTimer.end("Dependency: \(dependency)")
    }
    BuildTimer.end("Dependencies Compilation")

    BuildTimer.start("Target Module")
    try await buildModule(moduleName)
    BuildTimer.end("Target Module")

    BuildTimer.end("Module Build")
    BuildTimer.summarize()
  }

  // MARK: Private

  private let config: BuildConfig
  private let fileManager: FileManager
  private let simulatorManager: SimulatorManager
  private let dependencyGraph: DependencyGraph
  private let useCache: Bool

  private func resolveBuildOrder() -> UniquedSequence<[String], String> {
    var buildOrder: [String] = []
    for moduleName in dependencyGraph.adjacencyList.keys {
      let dependencies = dependencyGraph.resolveDependencies(for: moduleName)
      buildOrder.append(contentsOf: dependencies)
    }
    return buildOrder.uniqued()
  }

  private func prepareDirectories() throws {
    try? fileManager.removeItem(atPath: config.buildDir)

    try fileManager.createDirectory(atPath: config.buildDir, withIntermediateDirectories: true)
  }

  private func createAppBundle() throws {
    let appBundlePath = "\(config.buildDir)/\(config.appName).app"
    try? fileManager.removeItem(atPath: appBundlePath)
    try fileManager.createDirectory(atPath: appBundlePath, withIntermediateDirectories: true)

    try fileManager.moveItem(
      atPath: "\(config.buildDir)/\(config.appName)",
      toPath: "\(appBundlePath)/\(config.appName)")

    try setExecutablePermissions(atPath: "\(appBundlePath)/\(config.appName)")

    try signApp(at: appBundlePath)
  }

  private func signApp(at path: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = [
      "--force",
      "--sign", "-",
      "--preserve-metadata=identifier,entitlements,flags",
      "--generate-entitlement-der",
      path,
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

  private func setExecutablePermissions(atPath path: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/chmod")
    process.arguments = ["755", path]
    try process.run()
    process.waitUntilExit()
  }
}

extension BuildSystem {
  private func findSwiftFiles(in directory: String) throws -> [String] {
    BuildLogger.info("Finding swift files in directory: \(directory)")

    let url = URL(fileURLWithPath: directory)
    let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles])

    var swiftFiles: [String] = []

    while let fileURL = enumerator?.nextObject() as? URL {
      if fileURL.pathExtension == "swift" {
        swiftFiles.append(fileURL.path)
      }
    }

    BuildLogger.debug("Found Swift files: \(swiftFiles)")

    guard !swiftFiles.isEmpty else {
      throw BuildError.compilationFailed("No Swift files found in \(directory)")
    }

    return swiftFiles
  }
}

extension BuildSystem {
  private func buildModule(_ moduleName: String) async throws {
    let absoluteSourceDir = URL(fileURLWithPath: config.sourceDir).standardizedFileURL.path
    let absoluteBuildDir = URL(fileURLWithPath: config.buildDir).standardizedFileURL.path

    let modulePath = "\(absoluteSourceDir)/\(moduleName)/Sources"
    let moduleBuildPath = "\(absoluteBuildDir)/\(moduleName)"

    BuildLogger.info("Building module at path: \(modulePath)")
    BuildLogger.debug("Module build path: \(moduleBuildPath)")

    try fileManager.createDirectory(atPath: moduleBuildPath, withIntermediateDirectories: true)

    let sources = try findSwiftFiles(in: modulePath)
    BuildLogger.debug("Found source files: \(sources)")

    let outputFileMap = try createOutputFileMap(sources: sources, buildPath: moduleBuildPath)
    let outputFileMapPath = "\(moduleBuildPath)/output-file-map.json"
    try outputFileMap.write(toFile: outputFileMapPath, atomically: true, encoding: .utf8)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

    // Set the current directory to the build path
    process.currentDirectoryURL = URL(fileURLWithPath: moduleBuildPath)

    let cache = ModuleCache(cacheDir: "\(config.buildDir)/../.cache", fileManager: fileManager)
    var args = [
      "-sdk", config.sdkPath,
      "-target", "\(config.simulatorArch)-apple-ios\(config.deploymentTarget)-simulator",
      "-emit-module",
      "-emit-module-path", ".",
      "-emit-dependencies",
      "-emit-objc-header",
      "-emit-objc-header-path", "\(moduleName).h",
      "-module-name", moduleName,
      "-output-file-map", "output-file-map.json",
      "-parse-as-library",
      "-c",
      "-swift-version", "5",
      "-whole-module-optimization",
    ]

    let dependencies = dependencyGraph.adjacencyList[moduleName] ?? []
    for dependency in dependencies {
      args += ["-I", "\(absoluteBuildDir)/\(dependency)"]
    }

    let key = try cache.computeModuleKey(
      name: moduleName,
      sourceFiles: sources,
      dependencies: [:],
      compilerArgs: args)

    if cache.hasCachedModule(key: key), useCache {
      BuildLogger.info("Using cached version of module \(moduleName)")
      try cache.restoreModule(key: key, buildDir: absoluteBuildDir)
      return
    }

    args += sources

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe
    process.arguments = args

    let fullCommand = (["/usr/bin/swiftc"] + args).joined(separator: " ")
    BuildLogger.debug("\nExecuting compiler command:\n\(fullCommand)\n")

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      BuildLogger.debug("Compiler output for \(moduleName):\n\(output)")
    }

    if process.terminationStatus != 0 {
      throw BuildError.compilationFailed("Failed to build module \(moduleName)")
    }

    try cache.cacheModule(
      key: key,
      buildDir: absoluteBuildDir,
      artifacts: [
        "\(moduleName)/\(moduleName).d",
        "\(moduleName)/\(moduleName).h",
        "\(moduleName)/\(moduleName).swiftmodule",
        "\(moduleName)/\(moduleName).emit-module.d",
        "\(moduleName)/\(moduleName).o",
        "\(moduleName)/module.swiftdeps",
      ])
  }

  private func createOutputFileMap(sources _: [String], buildPath: String) throws -> String {
    // With WMO, we only need the special empty key for whole-module outputs
    let map: [String: [String: String]] = [
      "": [
        "object": "\(URL(fileURLWithPath: buildPath).lastPathComponent).o",
        "swift-dependencies": "module.swiftdeps",
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: map, options: .prettyPrinted)
    let str = String(data: jsonData, encoding: .utf8)!
    BuildLogger.debug("Output file map:\n\(str)")
    return str
  }

  private func compileAndLink() async throws {
    let mainSources = try findSwiftFiles(in: "\(config.sourceDir)/Sources")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

    let simulatorLibPath =
      "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator"
    let swiftLibPath = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"

    var args = [
      "-sdk", config.sdkPath,
      "-target", "\(config.simulatorArch)-apple-ios\(config.deploymentTarget)-simulator",
      "-emit-executable",
      "-o", "\(config.buildDir)/\(config.appName)",
      "-L", simulatorLibPath,
      "-L", swiftLibPath,
      "-Xlinker", "-rpath", "-Xlinker", "@executable_path/Frameworks",
      "-Xlinker", "-rpath", "-Xlinker", simulatorLibPath,
      "-F", "\(config.sdkPath)/System/Library/Frameworks",
      "-framework", "SwiftUI",
      "-framework", "Foundation",
      "-framework", "UIKit",
      "-framework", "CoreGraphics",
      "-framework", "CoreServices",
      "-swift-version", "5",
      "-Xlinker", "-no_objc_category_merging",
    ]

    let buildOrder = resolveBuildOrder()
    for moduleName in buildOrder {
      args += ["-I", "\(config.buildDir)/\(moduleName)"]
      let objectPath = "\(config.buildDir)/\(moduleName)/\(moduleName).o"
      if FileManager.default.fileExists(atPath: objectPath) {
        args += [objectPath]
      } else {
        throw BuildError.compilationFailed("Object file not found at path: \(objectPath)")
      }
    }

    args += mainSources

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe
    process.arguments = args

    BuildLogger.debug("Compiling and linking with arguments: \(args.joined(separator: " "))")
    BuildLogger.info("Compiling \(config.appName)")
    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      BuildLogger.debug("Compiler output:\n\(output)")
    }

    if process.terminationStatus != 0 {
      throw BuildError.compilationFailed(String(data: data, encoding: .utf8) ?? "Unknown error")
    }
  }

}
