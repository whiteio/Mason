import ArgumentParser

// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

struct Mason: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mason",
        abstract: "A build system for iOS apps",
        version: "1.0.0"
    )

    @Option(name: .long, help: "Name of the app")
    var appName: String

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String

    @Option(name: .long, help: "Directory containing source files")
    var sourceDir: String = "Sources"

    @Option(name: .long, help: "Directory containing resources")
    var resourcesDir: String = "Resources"

    @Option(name: .long, help: "Build output directory")
    var buildDir: String = "build"

    @Option(name: .long, help: "IPA output directory")
    var ipaDir: String = "ipa"

    @Option(name: .long, help: "iOS deployment target")
    var deploymentTarget: String = "15.0"

    mutating func run() throws {
        print("Starting build process...")
        print("Source directory: \(sourceDir)")

        let config = BuildConfig(
            appName: appName,
            bundleId: bundleId,
            sourceDir: sourceDir,
            buildDir: buildDir,
            resourcesDir: resourcesDir,
            ipaDir: ipaDir,
            deploymentTarget: deploymentTarget
        )

        let mason = BuildSystem(config: config)

        // Since we're not in an async context, we need to run this synchronously
        let group = DispatchGroup()
        var buildError: Error?

        group.enter()
        Task {
            do {
                try await mason.build()
                group.leave()
            } catch {
                buildError = error
                group.leave()
            }
        }

        group.wait()

        if let error = buildError {
            throw error
        }

        print("Successfully built \(appName).ipa")
        print("IPA location: \(ipaDir)/\(appName).ipa")
    }
}

Mason.main()
