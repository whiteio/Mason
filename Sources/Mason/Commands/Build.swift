//
//  Build.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import ArgumentParser
import Foundation
import Yams

// MARK: - Constants

enum Constants {
  static let buildDir = ".build"
}

// MARK: - Build

struct Build: ParsableCommand {

  // MARK: Internal

  static let configuration = CommandConfiguration(
    commandName: "build",
    abstract: "Build the specified target and install it to the simulator")

  @Option(name: .shortAndLong, help: "The source directory containing the project")
  var source: String

  @Option(name: .shortAndLong, help: "The name of the module to build (optional)")
  var module: String?

  @Flag(name: .long, help: "Force a clean build ignoring the module cache")
  var clean = false

  func validate() throws {
    let url = URL(fileURLWithPath: source)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ValidationError("The specified target directory does not exist: \(url.path)")
    }

    if let moduleName = module {
      let moduleUrl = url.appendingPathComponent(moduleName)
      guard FileManager.default.fileExists(atPath: moduleUrl.path) else {
        throw ValidationError("The specified module does not exist: \(moduleUrl.path)")
      }
    }
  }

  func run() throws {
    let group = DispatchGroup()
    group.enter()

    var asyncError: Error?

    Task {
      do {
        BuildLogger.debug("Parsing configuration and building dependency graph...")
        BuildLogger.debug("Source directory: \(source)")
        if let moduleName = module {
          BuildLogger.info("Building single module: \(moduleName)")
        }
        if clean {
          BuildLogger.info("Performing clean build - module cache will be ignored")
        }

        let appConfig = try parseAppConfig()
        BuildLogger.debug("App Name: \(appConfig.appName)")
        BuildLogger.debug("Modules: \(appConfig.modules)")

        let dependencyGraph = try buildDependencyGraph(appConfig: appConfig)

        if let moduleName = module {
          // Verify module exists in dependency graph
          guard dependencyGraph.adjacencyList.keys.contains(moduleName) else {
            throw ValidationError("Module '\(moduleName)' not found in dependency graph")
          }
        }

        let buildConfig = BuildConfig(
          appName: appConfig.appName,
          bundleId: appConfig.bundleId,
          sourceDir: source,
          buildDir: "\(source)/\(Constants.buildDir)",
          resourcesDir: "\(source)/\(appConfig.resourcesDir)",
          deploymentTarget: appConfig.deploymentTarget)

        let simulatorManager = SimulatorManager()
        let buildSystem = BuildSystem(
          config: buildConfig,
          simulatorManager: simulatorManager,
          dependencyGraph: dependencyGraph,
          useCache: !clean)

        BuildLogger.info("Starting build process...")
        if let moduleName = module {
          // Build single module
          try await buildSystem.buildSingleModule(moduleName)
          BuildLogger.info("Module '\(moduleName)' built successfully!")
        } else {
          // Build full app
          try await buildSystem.buildApp()
          BuildLogger.info("App built and installed successfully!")
        }
      } catch {
        asyncError = error
      }

      group.leave()
    }

    group.wait()

    if let error = asyncError {
      throw error
    }
  }

  // MARK: Private

  private func parseAppConfig() throws -> AppConfig {
    let appConfigPath = "\(source)/app.yml"
    let appConfigContent = try String(contentsOfFile: appConfigPath, encoding: .utf8)
    let decoder = YAMLDecoder()
    return try decoder.decode(AppConfig.self, from: appConfigContent)
  }

  private func buildDependencyGraph(appConfig: AppConfig) throws -> DependencyGraph {
    let dependencyGraph = DependencyGraph()
    var processedModules = Set<String>()

    func processModule(_ moduleName: String) throws {
      // Skip if we've already processed this module
      guard !processedModules.contains(moduleName) else {
        return
      }

      processedModules.insert(moduleName)

      // Read and parse the module config
      let moduleConfigPath = "\(source)/\(moduleName)/module.yml"
      let moduleConfigContent = try String(contentsOfFile: moduleConfigPath, encoding: .utf8)
      let moduleConfig = try YAMLDecoder().decode(ModuleConfig.self, from: moduleConfigContent)

      BuildLogger.debug("Processing module: \(moduleConfig.moduleName)")
      BuildLogger.debug("Dependencies: \(moduleConfig.dependencies ?? [])")

      // Add this module to the graph
      dependencyGraph.addModule(moduleConfig.moduleName, dependencies: moduleConfig.dependencies)

      // Recursively process all dependencies
      if let dependencies = moduleConfig.dependencies {
        for dependency in dependencies {
          try processModule(dependency)
        }
      }
    }

    // Start processing from the root modules in app.yml
    for moduleName in appConfig.modules {
      try processModule(moduleName)
    }

    BuildLogger.debug("Complete dependency graph: \(dependencyGraph.adjacencyList)")
    return dependencyGraph
  }
}
