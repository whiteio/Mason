//
//  Build.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Yams
import ArgumentParser
import Foundation

struct Constants {
    static let buildDir: String = ".build"
}

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the specified target and install it to the simulator"
    )
    
    @Argument(help: "The target to build (path to project directory)")
    var target: String
        
    func validate() throws {
        let url = URL(fileURLWithPath: target)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("The specified target directory does not exist: \(url.path)")
        }
    }
    
    func run() throws {
        let group = DispatchGroup()
        group.enter()
        
        var asyncError: Error?
        
        Task {
            do {
                BuildLogger.debug("Parsing configuration and building dependency graph...")
                BuildLogger.debug("Target directory: \(target)")

                let appConfig = try parseAppConfig()
                print("App Name: \(appConfig.appName)")
                print("Modules: \(appConfig.modules)")

                let dependencyGraph = try buildDependencyGraph(appConfig: appConfig)
                
                let buildConfig = BuildConfig(
                    appName: appConfig.appName,
                    bundleId: appConfig.bundleId,
                    sourceDir: target,
                    buildDir: "\(target)/\(Constants.buildDir)",
                    resourcesDir: "\(target)/\(appConfig.resourcesDir)",
                    deploymentTarget: appConfig.deploymentTarget
                )

                let simulatorManager = SimulatorManager()
                
                let buildSystem = BuildSystem(
                    config: buildConfig,
                    simulatorManager: simulatorManager,
                    dependencyGraph: dependencyGraph
                )

                BuildLogger.info("Starting build process...")
                try await buildSystem.build()
                BuildLogger.info("Build completed successfully!")
                
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
    
    private func parseAppConfig() throws -> AppConfig {
        let appConfigPath = "\(target)/app.yml"
        let appConfigContent = try String(contentsOfFile: appConfigPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(AppConfig.self, from: appConfigContent)
    }

    private func buildDependencyGraph(appConfig: AppConfig) throws -> DependencyGraph {
        let dependencyGraph = DependencyGraph()

        for moduleName in appConfig.modules {
            let moduleConfigPath = "\(target)/\(moduleName)/module.yml"
            let moduleConfigContent = try String(contentsOfFile: moduleConfigPath, encoding: .utf8)
            let moduleConfig = try YAMLDecoder().decode(ModuleConfig.self, from: moduleConfigContent)

            BuildLogger.debug("Parsed module: \(moduleConfig.moduleName)")
            BuildLogger.debug("Dependencies: \(moduleConfig.dependencies ?? [])")

            dependencyGraph.addModule(moduleConfig.moduleName, dependencies: moduleConfig.dependencies)
        }

        return dependencyGraph
    }
}
