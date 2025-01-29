//
//  ModuleBuildOperation.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation

struct ModuleBuildOperation: Sendable {

  // MARK: Internal

  let moduleName: String
  let config: BuildConfig
  let useCache: Bool
  let buildDir: String
  let sourceDir: String
  let dependencies: [String]

  func execute() async throws {
    await BuildTimer.start("Module: \(moduleName)")
    try await buildModule()
    await BuildTimer.end("Module: \(moduleName)")
  }

  // MARK: Private

  private func buildModule() async throws {
    let fileOps = FileOperationActor()

    let absoluteSourceDir = URL(fileURLWithPath: sourceDir).standardizedFileURL.path
    let absoluteBuildDir = URL(fileURLWithPath: buildDir).standardizedFileURL.path

    let modulePath = "\(absoluteSourceDir)/\(moduleName)/Sources"
    let moduleBuildPath = "\(absoluteBuildDir)/\(moduleName)"

    BuildLogger.info("Building module at path: \(modulePath)")

    try await fileOps.createDirectory(atPath: moduleBuildPath)

    let sources = try await fileOps.findSwiftFiles(in: modulePath)
    BuildLogger.debug("Found source files: \(sources)")

    let outputFileMap = try createOutputFileMap(sources: sources, buildPath: moduleBuildPath)
    let outputFileMapPath = "\(moduleBuildPath)/output-file-map.json"
    try await fileOps.writeFile(outputFileMap, toPath: outputFileMapPath)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
    process.currentDirectoryURL = URL(fileURLWithPath: moduleBuildPath)

    // Create ModuleCache with isolated file operations
    let cache = ModuleCache(cacheDir: "\(config.buildDir)/../.cache", fileManager: .default)
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
      "-swift-version", "\(config.swiftVersion)",
      "-whole-module-optimization",
    ]

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
    let map: [String: [String: String]] = [
      "": [
        "object": "\(URL(fileURLWithPath: buildPath).lastPathComponent).o",
        "swift-dependencies": "module.swiftdeps",
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: map, options: .prettyPrinted)
    return String(data: jsonData, encoding: .utf8)!
  }
}
