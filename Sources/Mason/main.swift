import ArgumentParser
import Foundation
import Yams

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
        // Ensure the source directory exists and is absolute
        let url = URL(fileURLWithPath: sourceDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("The specified source directory does not exist: \(url.path)")
        }
    }

    func run() throws {
        // Create a Task to handle async operations
        let group = DispatchGroup()
        group.enter()
        
        var asyncError: Error?
        
        Task {
            do {
                print("Parsing configuration and building dependency graph...")
                print("Source directory: \(sourceDirectory)")

                // Parse app configuration
                let appConfig = try parseAppConfig()
                print("App Name: \(appConfig.appName)")
                print("Modules: \(appConfig.modules)")

                // Build dependency graph
                let dependencyGraph = try buildDependencyGraph(appConfig: appConfig)
                
                // Initialize build configuration with the correct source directory
                let buildConfig = BuildConfig(
                    appName: appConfig.appName,
                    bundleId: appConfig.bundleId,
                    sourceDir: sourceDirectory,  // Use the command-line provided path
                    buildDir: "\(sourceDirectory)/\(appConfig.buildDir)",
                    resourcesDir: "\(sourceDirectory)/\(appConfig.resourcesDir)",
                    ipaDir: "\(sourceDirectory)/\(appConfig.ipaDir)",
                    deploymentTarget: appConfig.deploymentTarget
                )

                // Initialize simulator manager
                let simulatorManager = SimulatorManager()

                // Initialize and run build system
                let buildSystem = BuildSystem(
                    config: buildConfig,
                    simulatorManager: simulatorManager,
                    dependencyGraph: dependencyGraph
                )

                print("Starting build process...")
                try await buildSystem.build()
                print("Build completed successfully!")
                
            } catch let error as BuildError {
                switch error {
                case .compilationFailed(let message):
                    print("Compilation failed: \(message)")
                case .resourceProcessingFailed(let message):
                    print("Resource processing failed: \(message)")
                case .bundleCreationFailed(let message):
                    print("Bundle creation failed: \(message)")
                case .ipaCreationFailed(let message):
                    print("IPA creation failed: \(message)")
                case .invalidPath(let message):
                    print("Invalid path: \(message)")
                case .signingFailed(let message):
                    print("Signing failed: \(message)")
                case .launchFailed(let message):
                    print("Launch failed: \(message)")
                case .installationFailed(let message):
                    print("Installation failed: \(message)")
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

            print("Parsed module: \(moduleConfig.moduleName)")
            print("Dependencies: \(moduleConfig.dependencies ?? [])")

            dependencyGraph.addModule(moduleConfig.moduleName, dependencies: moduleConfig.dependencies)
        }

        // Validate dependencies
        for moduleName in appConfig.modules {
            let dependencies = dependencyGraph.resolveDependencies(for: moduleName)
            print("Module \(moduleName) depends on: \(dependencies)")
        }

        return dependencyGraph
    }
}

Mason.main()
