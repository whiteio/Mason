//
//  Clean.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import ArgumentParser
import os
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
        os_log("Cleaning build artifacts from \(target)")
        
        // Parse app config to get build directories
        let appConfig = try parseAppConfig()
        
        let dirsToClean = [
            "\(target)/\(appConfig.buildDir)",
            "\(target)/\(appConfig.ipaDir)"
        ]
        
        let fileManager = FileManager.default
        
        for dir in dirsToClean {
            if fileManager.fileExists(atPath: dir) {
                do {
                    try fileManager.removeItem(atPath: dir)
                    print("Removed \(dir)")
                } catch {
                    print("Failed to remove \(dir): \(error.localizedDescription)")
                }
            } else {
                print("Directory already clean: \(dir)")
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
                            print("Removed \(itemPath)")
                        }
                    }
                } catch {
                    print("Failed to clean module directory \(modulePath): \(error.localizedDescription)")
                }
            }
        }
        
        print("Clean completed")
    }
    
    private func parseAppConfig() throws -> AppConfig {
        let appConfigPath = "\(target)/app.yml"
        let appConfigContent = try String(contentsOfFile: appConfigPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(AppConfig.self, from: appConfigContent)
    }
}
