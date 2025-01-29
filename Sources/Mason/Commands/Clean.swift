//
//  Clean.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import ArgumentParser
import Foundation
import Yams

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Remove build artifacts"
    )

    @Argument(help: "The target to clean (path to project directory)")
    var target: String

    func validate() throws {
        let url = URL(fileURLWithPath: target)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("The specified target directory does not exist: \(url.path)")
        }
    }

    func run() throws {
        BuildLogger.info("Cleaning build artifacts from \(target)")

        // Parse app config to get build directories
        let appConfig = try parseAppConfig()

        let dirsToClean = [
            "\(target)/\(Constants.buildDir)",
        ]

        let fileManager = FileManager.default

        for dir in dirsToClean {
            if fileManager.fileExists(atPath: dir) {
                do {
                    try fileManager.removeItem(atPath: dir)
                    BuildLogger.debug("Removed \(dir)")
                } catch {
                    BuildLogger.debug("Failed to remove \(dir): \(error.localizedDescription)")
                }
            } else {
                BuildLogger.debug("Directory already clean: \(dir)")
            }
        }

        for moduleName in appConfig.modules {
            let modulePath = "\(target)/\(moduleName)"
            if fileManager.fileExists(atPath: modulePath) {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: modulePath)
                    for item in contents {
                        if item.hasSuffix(".swiftmodule") || item.hasSuffix(".o") {
                            let itemPath = "\(modulePath)/\(item)"
                            try fileManager.removeItem(atPath: itemPath)
                            BuildLogger.debug("Removed \(itemPath)")
                        }
                    }
                } catch {
                    BuildLogger.error("Failed to clean module directory \(modulePath): \(error.localizedDescription)")
                }
            }
        }

        BuildLogger.info("Clean completed")
    }

    private func parseAppConfig() throws -> AppConfig {
        let appConfigPath = "\(target)/app.yml"
        let appConfigContent = try String(contentsOfFile: appConfigPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(AppConfig.self, from: appConfigContent)
    }
}
