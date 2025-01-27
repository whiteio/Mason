import ArgumentParser
import Foundation
import Yams
import os

struct Mason: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mason",
        abstract: "A build system for iOS apps",
        version: "1.0.0"
    )
    
    @Argument(
        help: "The root directory of the project"
    )
    var sourceDirectory: String

    func validate() throws {
        let url = URL(fileURLWithPath: sourceDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("The specified source directory does not exist: \(url.path)")
        }
    }

    func run() throws {
        let group = DispatchGroup()
        group.enter()
        
        var asyncError: Error?
        
        Task {
            do {
                os_log("Parsing configuration and building dependency graph...")
                os_log("Source directory: \(sourceDirectory)")

                let appConfig = try parseAppConfig()
                print("App Name: \(appConfig.appName)")
                print("Modules: \(appConfig.modules)")

                let dependencyGraph = try buildDependencyGraph(appConfig: appConfig)
                
                let buildConfig = BuildConfig(
                    appName: appConfig.appName,
                    bundleId: appConfig.bundleId,
                    sourceDir: sourceDirectory,  // Use the command-line provided path
                    buildDir: "\(sourceDirectory)/\(appConfig.buildDir)",
                    resourcesDir: "\(sourceDirectory)/\(appConfig.resourcesDir)",
                    ipaDir: "\(sourceDirectory)/\(appConfig.ipaDir)",
                    deploymentTarget: appConfig.deploymentTarget
                )

                let simulatorManager = SimulatorManager()

                let buildSystem = BuildSystem(
                    config: buildConfig,
                    simulatorManager: simulatorManager,
                    dependencyGraph: dependencyGraph
                )

                os_log("Starting build process...")
                try await buildSystem.build()
                os_log("Build completed successfully!")
                
            } catch let error as BuildError {
                switch error {
                case .compilationFailed(let message):
                    os_log("Compilation failed: \(message)")
                case .resourceProcessingFailed(let message):
                    os_log("Resource processing failed: \(message)")
                case .bundleCreationFailed(let message):
                    os_log("Bundle creation failed: \(message)")
                case .ipaCreationFailed(let message):
                    os_log("IPA creation failed: \(message)")
                case .invalidPath(let message):
                    os_log("Invalid path: \(message)")
                case .signingFailed(let message):
                    os_log("Signing failed: \(message)")
                case .launchFailed(let message):
                    os_log("Launch failed: \(message)")
                case .installationFailed(let message):
                    os_log("Installation failed: \(message)")
                }
                asyncError = error
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
        let appConfigPath = "\(sourceDirectory)/app.yml"
        let appConfigContent = try String(contentsOfFile: appConfigPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(AppConfig.self, from: appConfigContent)
    }

    private func buildDependencyGraph(appConfig: AppConfig) throws -> DependencyGraph {
        let dependencyGraph = DependencyGraph()

        // Parse each module config and build the dependency graph
        for moduleName in appConfig.modules {
            let moduleConfigPath = "\(sourceDirectory)/\(moduleName)/module.yml"
            let moduleConfigContent = try String(contentsOfFile: moduleConfigPath, encoding: .utf8)
            let moduleConfig = try YAMLDecoder().decode(ModuleConfig.self, from: moduleConfigContent)

            os_log("Parsed module: \(moduleConfig.moduleName)")
            os_log("Dependencies: \(moduleConfig.dependencies ?? [])")

            dependencyGraph.addModule(moduleConfig.moduleName, dependencies: moduleConfig.dependencies)
        }

        // Validate dependencies
        for moduleName in appConfig.modules {
            let dependencies = dependencyGraph.resolveDependencies(for: moduleName)
            os_log("Module \(moduleName) depends on: \(dependencies)")
        }

        return dependencyGraph
    }
}

Mason.main()
