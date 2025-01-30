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
    await BuildTimer.reset()
    await BuildTimer.start("Total Build")

    await BuildTimer.start("Prepare Directories")
    try prepareDirectories()
    await BuildTimer.end("Prepare Directories")

    await BuildTimer.start("Module Compilation")
    let buildOrder = resolveBuildOrder()
    try await buildModulesInParallel(Array(buildOrder))
    await BuildTimer.end("Module Compilation")

    await BuildTimer.start("Final Link")
    try await compileAndLink()
    await BuildTimer.end("Final Link")

    await BuildTimer.start("Bundle Creation")
    try createAppBundle()
    try processResources()
    await BuildTimer.end("Bundle Creation")

    await BuildTimer.start("Installation")
    try simulatorManager.install(config)
    await BuildTimer.end("Installation")

    await BuildTimer.end("Total Build")
    await BuildTimer.summarize()
  }

  func buildSingleModule(_ moduleName: String) async throws {
    await BuildTimer.reset()
    await BuildTimer.start("Module Build")

    await BuildTimer.start("Prepare Directories")
    try prepareDirectories()
    await BuildTimer.end("Prepare Directories")

    await BuildTimer.start("Dependency Resolution")
    let dependencies = dependencyGraph.resolveDependencies(for: moduleName)
    let moduleDependencies = dependencies.filter { $0 != moduleName }
    BuildLogger.debug("Dependencies for \(moduleName): \(moduleDependencies)")
    await BuildTimer.end("Dependency Resolution")

    await BuildTimer.start("Dependencies Compilation")
    var modulesByLevel: [Int: Set<String>] = [:]
    for module in moduleDependencies {
      let deps = dependencyGraph.resolveDependencies(for: module)
      let level = deps.count
      modulesByLevel[level, default: []].insert(module)
    }

    let tracker = ParallelBuildTracker()
    for level in modulesByLevel.keys.sorted() {
      guard let modulesAtLevel = modulesByLevel[level] else { continue }

      BuildLogger.info("Building level \(level) dependencies in parallel: \(modulesAtLevel.joined(separator: ", "))")

      try await withThrowingTaskGroup(of: Void.self) { group in
        for module in modulesAtLevel {
          let operation = ModuleBuildOperation(
            moduleName: module,
            config: config,
            useCache: useCache,
            buildDir: config.buildDir,
            sourceDir: config.sourceDir,
            dependencies: dependencyGraph.adjacencyList[module] ?? [])

          group.addTask {
            await tracker.moduleStarted(operation.moduleName)
            defer { Task { await tracker.moduleFinished(operation.moduleName) } }
            try await operation.execute()
          }
        }

        try await group.waitForAll()
        await tracker.logLevelStatistics(level)
      }
    }
    await BuildTimer.end("Dependencies Compilation")

    // Build the target module
    await BuildTimer.start("Target Module")
    let targetOperation = ModuleBuildOperation(
      moduleName: moduleName,
      config: config,
      useCache: useCache,
      buildDir: config.buildDir,
      sourceDir: config.sourceDir,
      dependencies: dependencyGraph.adjacencyList[moduleName] ?? [])
    try await targetOperation.execute()
    await BuildTimer.end("Target Module")

    await BuildTimer.end("Module Build")
    await BuildTimer.summarize()
  }

  // MARK: Private

  private let config: BuildConfig
  private let fileManager: FileManager
  private let simulatorManager: SimulatorManager
  private let dependencyGraph: DependencyGraph
  private let useCache: Bool

  private func buildModulesInParallel(_ modules: [String]) async throws {
    let tracker = ParallelBuildTracker()

    // Group modules by their dependency level
    var modulesByLevel: [Int: Set<String>] = [:]
    for module in modules {
      let dependencies = dependencyGraph.resolveDependencies(for: module)
      let level = dependencies.count
      modulesByLevel[level, default: []].insert(module)
    }

    BuildLogger.info("Parallel build plan:")
    for (level, modules) in modulesByLevel {
      BuildLogger.info("Level \(level): \(modules.joined(separator: ", "))")
    }

    // Build modules level by level
    for level in modulesByLevel.keys.sorted() {
      guard let modulesAtLevel = modulesByLevel[level] else { continue }

      BuildLogger.info("Building level \(level) modules in parallel: \(modulesAtLevel.joined(separator: ", "))")

      try await withThrowingTaskGroup(of: Void.self) { group in
        for module in modulesAtLevel {
          let operation = ModuleBuildOperation(
            moduleName: module,
            config: config,
            useCache: useCache,
            buildDir: config.buildDir,
            sourceDir: config.sourceDir,
            dependencies: dependencyGraph.adjacencyList[module] ?? [])

          group.addTask { [operation] in
            await tracker.moduleStarted(operation.moduleName)
            defer {
              Task {
                await tracker.moduleFinished(operation.moduleName)
              }
            }

            try await operation.execute()
          }
        }

        try await group.waitForAll()
      }

      await tracker.logLevelStatistics(level)
    }

    await tracker.logFinalStatistics()
  }

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
    try createInfoPlist(at: "\(appBundlePath)/Info.plist")
  }

  private func createInfoPlist(at path: String) throws {
    // Base plist entries that are always required
    var plistDict: [String: Any] = [
      "CFBundleDevelopmentRegion": "en",
      "CFBundleExecutable": config.appName,
      "CFBundleIdentifier": config.bundleId,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": config.appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": config.plist.version,
      "CFBundleVersion": config.plist.buildNumber,
      "MinimumOSVersion": config.deploymentTarget,
      "DTPlatformName": "iphonesimulator",
      "DTPlatformVersion": "17.0",
      "DTSDKName": "iphonesimulator17.0",
    ]

    // Add launch screen if enabled
    if config.plist.infoPlist.launchScreen {
      plistDict["UILaunchScreen"] = [String: Any]()
    }

    // Add device capabilities
    plistDict["UIRequiredDeviceCapabilities"] = config.plist.infoPlist.requiredDeviceCapabilities

    // Add orientations
    plistDict["UISupportedInterfaceOrientations"] = config.plist.infoPlist.supportedOrientations

    // Convert PlistValue custom entries to standard types
    let customEntries = convertPlistValues(config.plist.infoPlist.customEntries)

    // Merge in any custom entries
    for (key, value) in customEntries {
      plistDict[key] = value
    }

    // Convert to property list format
    let data = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0)
    try data.write(to: URL(fileURLWithPath: path))
  }

  private func convertPlistValues(_ values: [String: PlistValue]) -> [String: Any] {
    var result = [String: Any]()

    for (key, value) in values {
      result[key] = convertPlistValue(value)
    }

    return result
  }

  private func convertPlistValue(_ value: PlistValue) -> Any {
    switch value {
    case .string(let str):
      str
    case .bool(let bool):
      bool
    case .integer(let int):
      int
    case .array(let arr):
      arr.map { convertPlistValue($0) }
    case .dictionary(let dict):
      convertPlistValues(dict)
    }
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
